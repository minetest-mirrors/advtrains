-- Signal API implementation

local DANGER = {
	main = 0,
	shunt = false,
}
advtrains.interlocking.DANGER = DANGER

advtrains.interlocking.GENERIC_FREE = {
	main = -1,
	shunt = false,
	dst = false,
}
advtrains.interlocking.FULL_FREE = {
	main = -1,
	shunt = false,
	proceed_as_main = true,
}

local function convert_aspect_if_necessary(asp)
	if type(asp.main) == "table" then
		local newasp = {} 
		if asp.main.free then
			newasp.main = asp.main.speed
		else
			newasp.main = 0
		end
		if asp.dst and asp.dst.free then
			newasp.dst = asp.dst.speed
		else
			newasp.dst = 0
		end
		newasp.proceed_as_main = asp.shunt.proceed_as_main
		newasp.shunt = asp.shunt.free
		-- Note: info table not transferred, it's not used right now
		return newasp
	end
	return asp
end
advtrains.interlocking.signal_convert_aspect_if_necessary = convert_aspect_if_necessary

function advtrains.interlocking.update_signal_aspect(tcbs, skipdst)
	if tcbs.signal then
		local asp = tcbs.aspect or DANGER
		advtrains.interlocking.signal_set_aspect(tcbs.signal, asp, skipdst)
	end
end

function advtrains.interlocking.signal_can_dig(pos)
	return not advtrains.interlocking.db.get_sigd_for_signal(pos)
end

function advtrains.interlocking.signal_after_dig(pos)
	-- clear influence point

	advtrains.interlocking.signal_clear_aspect(pos)
	advtrains.distant.unassign_all(pos, true)
end

-- should be called when aspect has changed on this signal.
function advtrains.interlocking.signal_on_aspect_changed(pos)
	local ipts, iconn = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if not ipts then return end
	local ipos = minetest.string_to_pos(ipts)

	-- FIXME: invalidate_all_paths_ahead does not appear to always work as expected
	--advtrains.invalidate_all_paths_ahead(ipos)
	minetest.after(0, advtrains.invalidate_all_paths, ipos)
end

function advtrains.interlocking.signal_rc_handler(pos, node, player, itemstack, pointed_thing)
	local pname = player:get_player_name()
	local control = player:get_player_control()
	if control.aux1 then
		advtrains.interlocking.show_ip_form(pos, pname)
		return
	end
	advtrains.interlocking.show_signal_form(pos, node, pname)
end
	
function advtrains.interlocking.show_signal_form(pos, node, pname)
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd then
		advtrains.interlocking.show_signalling_form(sigd, pname)
	else
		local ndef = minetest.registered_nodes[node.name]
		if ndef.advtrains and ndef.advtrains.set_aspect then
			-- permit to set aspect manually
			local function callback(pname, aspect)
				advtrains.interlocking.signal_set_aspect(pos, aspect)
			end
			local isasp = advtrains.interlocking.signal_get_aspect(pos, node)
			
			advtrains.interlocking.show_signal_aspect_selector(
				pname,
				ndef.advtrains.supported_aspects,
				pos, callback,
				isasp)
		else
			--static signal - only IP
			advtrains.interlocking.show_ip_form(pos, pname)
		end
	end
end

-- Returns the aspect the signal at pos is supposed to show
function advtrains.interlocking.signal_get_supposed_aspect(pos)
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd then
		local tcbs = advtrains.interlocking.db.get_tcbs(sigd)
		if tcbs.aspect then
			return convert_aspect_if_necessary(tcbs.aspect)
		end
	end
	return DANGER;
end

local players_assign_ip = {}

local function ipmarker(ipos, connid)
	local node_ok, conns, rhe = advtrains.get_rail_info_at(ipos, advtrains.all_tracktypes)
	if not node_ok then return end
	local yaw = advtrains.dir_to_angle(conns[connid].c)
	
	-- using tcbmarker here
	local obj = minetest.add_entity(vector.add(ipos, {x=0, y=0.2, z=0}), "advtrains_interlocking:tcbmarker")
	if not obj then return end
	obj:set_yaw(yaw)
	obj:set_properties({
		textures = { "at_il_signal_ip.png" },
	})
end

-- shows small info form for signal IP state/assignment
-- only_notset: show only if it is not set yet (used by signal tcb assignment)
function advtrains.interlocking.show_ip_form(pos, pname, only_notset)
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local form = "size[7,5]label[0.5,0.5;Signal at "..minetest.pos_to_string(pos).."]"
	form = form .. advtrains.interlocking.make_signal_formspec_tabheader(pname, pos, 7, 2)
	advtrains.interlocking.db.check_for_duplicate_ip(pos)
	local pts, connid = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if pts then
		form = form.."label[0.5,1.5;Influence point is set at "..pts.."/"..connid.."]"
		form = form.."button_exit[0.5,2.5;  5,1;set;Move]"
		form = form.."button_exit[0.5,3.5;  5,1;clear;Clear]"
		local ipos = minetest.string_to_pos(pts)
		ipmarker(ipos, connid)
	else
		form = form.."label[0.5,1.5;Influence point is not set.]"
		form = form.."label[0.5,2.0;It is recommended to set an influence point.]"
		form = form.."label[0.5,2.5;This is the point where trains will obey the signal.]"
		
		form = form.."button_exit[0.5,3.5;  5,1;set;Set]"
	end
	if not only_notset or not pts then
		minetest.show_formspec(pname, "at_il_ipassign_"..minetest.pos_to_string(pos), form)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if advtrains.interlocking.handle_signal_formspec_tabheader_fields(pname, fields) then
		return true
	end
	if not minetest.check_player_privs(pname, {train_operator=true, interlocking=true}) then
		return
	end
	local pts = string.match(formname, "^at_il_ipassign_([^_]+)$")
	local pos
	if pts then
		pos = minetest.string_to_pos(pts)
	end
	if pos then
		if fields.set then
			advtrains.interlocking.signal_init_ip_assign(pos, pname)
		elseif fields.clear then
			advtrains.interlocking.db.clear_ip_by_signalpos(pos)
		end
	end
end)

-- inits the signal IP assignment process
function advtrains.interlocking.signal_init_ip_assign(pos, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	--remove old IP
	--advtrains.interlocking.db.clear_ip_by_signalpos(pos)
	minetest.chat_send_player(pname, "Configuring Signal: Please look in train's driving direction and punch rail to set influence point.")
	
	players_assign_ip[pname] = pos
end

minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	-- IP assignment
	local signalpos = players_assign_ip[pname]
	if signalpos then
		if vector.distance(pos, signalpos)<=50 then
			local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
			if node_ok and #conns == 2 then
				
				local yaw = player:get_look_horizontal()
				local plconnid = advtrains.yawToClosestConn(yaw, conns)
				
				-- add assignment if not already present.
				local pts = advtrains.roundfloorpts(pos)
				if not advtrains.interlocking.db.get_ip_signal_asp(pts, plconnid) then
					advtrains.interlocking.db.set_ip_signal(pts, plconnid, signalpos)
					ipmarker(pos, plconnid)
					minetest.chat_send_player(pname, "Configuring Signal: Successfully set influence point")
				else
					minetest.chat_send_player(pname, "Configuring Signal: Influence point of another signal is already present!")
				end
			else
				minetest.chat_send_player(pname, "Configuring Signal: This is not a normal two-connection rail! Aborted.")
			end
		else
			minetest.chat_send_player(pname, "Configuring Signal: Node is too far away. Aborted.")
		end
		players_assign_ip[pname] = nil
	end
end)
