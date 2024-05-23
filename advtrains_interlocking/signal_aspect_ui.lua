local F = advtrains.formspec

function advtrains.interlocking.show_signal_form(pos, node, pname, aux_key)
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd and not aux_key then
		advtrains.interlocking.show_signalling_form(sigd, pname)
	else
		if advtrains.interlocking.signal.get_signal_cap_level(pos) >= 2 then
			advtrains.interlocking.show_ip_sa_form(pos, pname)
		else
			advtrains.interlocking.show_ip_form(pos, pname)
		end
	end
end

local players_assign_ip = {}
local players_assign_distant = {}

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

function advtrains.interlocking.make_ip_formspec_component(pos, x, y, w)
	advtrains.interlocking.db.check_for_duplicate_ip(pos)
	local pts, connid = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if pts then
		-- display marker
		local ipos = minetest.string_to_pos(pts)
		ipmarker(ipos, connid)
		return table.concat {
			F.S_label(x, y, "Influence point is set at @1.", string.format("%s/%s", pts, connid)),
			F.S_button_exit(x, y+0.5, w/2-0.125, "ip_set", "Modify"),
			F.S_button_exit(x+w/2+0.125, y+0.5, w/2-0.125, "ip_clear", "Clear"),
		}
	else
		return table.concat {
			F.S_label(x, y, "Influence point is not set."),
			F.S_button_exit(x, y+0.5, w, "ip_set", "Set influence point"),
		}
	end
end

-- shows small formspec to set the signal influence point
-- only_notset: show only if it is not set yet (used by signal tcb assignment)
function advtrains.interlocking.show_ip_form(pos, pname, only_notset)
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local ipform = advtrains.interlocking.make_ip_formspec_component(pos, 0.5, 0.5, 7)
	local form = {
		"formspec_version[4]",
		"size[8,2.25]",
		ipform,
	}
	if not only_notset or not pts then
		minetest.show_formspec(pname, "at_il_ipsaform_"..minetest.pos_to_string(pos), table.concat(form))
	end
end

-- shows larger formspec to set the signal influence point, main aspect and distant signal pos
-- only_notset: show only if it is not set yet (used by signal tcb assignment)
function advtrains.interlocking.show_ip_sa_form(pos, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local ipform = advtrains.interlocking.make_ip_formspec_component(pos, 0.5, 0.5, 7)
	local ma, rpos = advtrains.interlocking.signal.get_aspect(pos)
	local form = {
		"formspec_version[4]",
		"size[8,4.5]",
		ipform,
	}
	-- Create Signal aspect formspec elements
	local ndef = advtrains.ndb.get_ndef(pos)
	if ndef and ndef.advtrains then
		-- main aspect list
		if ndef.advtrains.main_aspects then
			local entries = { "<none>" }
			local sel = 1
			for i, mae in ipairs(ndef.advtrains.main_aspects) do
				entries[i+1] = mae.description
				if ma and ma.name == mae.name then
					sel = i+1
				end
			end
			form[#form+1] = F.dropdown(0.5, 2.5, 4, "sa_mainaspect", entries, sel, true)
		end
		-- distant signal assign (is shown either when main_aspect is not none, or when pure distant signal)
		if rpos then
			form[#form+1] = F.button_exit(0.5, 3.5, 4, "sa_undistant", "Dst: " .. minetest.pos_to_string(rpos))
		elseif (ma and not ma.halt) or not ndef.advtrains.main_aspects then
			form[#form+1] = F.button_exit(0.5, 3.5, 4, "sa_distant", "<assign distant>")
		end
	end
	
	minetest.show_formspec(pname, "at_il_ipsaform_"..minetest.pos_to_string(pos), table.concat(form))
end

function advtrains.interlocking.handle_ip_sa_formspec_fields(pname, pos, fields)
	if not (pos and minetest.check_player_privs(pname, {train_operator=true, interlocking=true})) then
		return
	end
	local ma, rpos = advtrains.interlocking.signal.get_aspect(pos)
	-- mainaspect dropdown
	if fields.sa_mainaspect then
		local idx = tonumber(fields.sa_mainaspect)
		local new_ma = nil
		if idx > 1 then
			local ndef = advtrains.ndb.get_ndef(pos)
			if ndef and ndef.advtrains and ndef.advtrains.main_aspects then
				new_ma = ndef.advtrains.main_aspects[idx - 1]
			end
		end
		if new_ma and (new_ma.name ~= ma.name or new_ma.speed ~= ma.speed) then
			advtrains.interlocking.signal.set_aspect(pos, new_ma.name, new_ma.speed, rpos)
		elseif not new_ma then
			-- reset everything
			advtrains.interlocking.signal.set_aspect(pos, nil, nil, nil)
		end
		
	end
	-- buttons
	if fields.ip_set then
		advtrains.interlocking.init_ip_assign(pos, pname)
		return
	elseif fields.ip_clear then
		advtrains.interlocking.db.clear_ip_by_signalpos(pos)
		return
	elseif fields.sa_distant then
		advtrains.interlocking.init_distant_assign(pos, pname)
		return
	elseif fields.sa_undistant then
		advtrains.interlocking.signal.set_aspect(pos, ma.name, ma.speed, nil)
		return
	end
	-- show the form again unless one of the buttons was clicked
	if not fields.quit then
		advtrains.interlocking.show_ip_sa_form(pos, pname)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local pts = string.match(formname, "^at_il_ipsaform_([^_]+)$")
	local pos
	if pts then
		pos = minetest.string_to_pos(pts)
	end
	if pos then
		advtrains.interlocking.handle_ip_sa_formspec_fields(pname, pos, fields)
	end
end)

-- inits the signal IP assignment process
function advtrains.interlocking.init_ip_assign(pos, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	--remove old IP
	--advtrains.interlocking.db.clear_ip_by_signalpos(pos)
	minetest.chat_send_player(pname, "Configuring Signal: Please look in train's driving direction and punch rail to set influence point.")
	
	players_assign_ip[pname] = pos
end

-- inits the distant signal assignment process
function advtrains.interlocking.init_distant_assign(pos, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	minetest.chat_send_player(pname, "Set distant signal: Punch the main signal to assign!")
	
	players_assign_distant[pname] = pos
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
	-- DST assignment
	signalpos = players_assign_distant[pname]
	if signalpos then
		-- get current mainaspect
		local ma, rpos = advtrains.interlocking.signal.get_aspect(signalpos)
		-- if punched pos is valid signal then set it as the new remote, otherwise nil
		local nrpos
		if advtrains.interlocking.signal.get_signal_cap_level(pos) > 1 then
			nrpos = pos
			if not ma then -- make sure that dst is never set without a main aspect (esp. for pure distant signal case)
				ma = { name = "_default" }
			end
			advtrains.interlocking.signal.set_aspect(signalpos, ma.name, ma.speed, nrpos)
		end
		players_assign_distant[pname] = nil
	end
end)

