-- Track Circuit Breaks and Track Sections - Player interaction

local players_assign_tcb = {}
local players_assign_signal = {}
local players_assign_xlink = {}
local players_link_ts = {}

local ildb = advtrains.interlocking.db
local ilrs = advtrains.interlocking.route

local sigd_equal = advtrains.interlocking.sigd_equal

local lntrans = { "A", "B" }

local function sigd_to_string(sigd)
	return minetest.pos_to_string(sigd.p).." / "..lntrans[sigd.s]
end
advtrains.interlocking.sigd_to_string = sigd_to_string

minetest.register_node("advtrains_interlocking:tcb_node", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="facedir",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/6, -1/2, -1/6, 1/6, 1/4, 1/6},
	},
	mesh = "at_il_tcb_node.obj",
	tiles = {"at_il_tcb_node.png"},
	description="Track Circuit Break",
	sunlight_propagates=true,
	groups = {
		cracky=3,
		not_blocking_trains=1,
		--save_in_at_nodedb=2,
		at_il_track_circuit_break = 1,
	},
	after_place_node = function(pos, node, player)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Unconfigured Track Circuit Break, right-click to assign.")
	end,
	on_rightclick = function(pos, node, player)
		local pname = player:get_player_name()
		if not minetest.check_player_privs(pname, "interlocking") then
			minetest.chat_send_player(pname, "Insufficient privileges to use this!")
			return
		end
		
		local meta = minetest.get_meta(pos)
		local tcbpts = meta:get_string("tcb_pos")
		if tcbpts ~= "" then
			local tcbpos = minetest.string_to_pos(tcbpts)
			local tcb = ildb.get_tcb(tcbpos)
			if tcb then
				advtrains.interlocking.show_tcb_form(tcbpos, pname)
			else
				minetest.chat_send_player(pname, "This TCB has been removed. Please dig marker.")
			end
		else
			--unconfigured
			minetest.chat_send_player(pname, "Configuring TCB: Please punch the rail you want to assign this TCB to.")
			
			players_assign_tcb[pname] = pos
		end	
	end,
	--on_punch = function(pos, node, player)
	--	local meta = minetest.get_meta(pos)
	--	local tcbpts = meta:get_string("tcb_pos")
	--	if tcbpts ~= "" then
	--		local tcbpos = minetest.string_to_pos(tcbpts)
	--		advtrains.interlocking.show_tcb_marker(tcbpos)
	--	end	
	--end,
	can_dig = function(pos, player)
		if player == nil then return false end

		local pname = player:get_player_name()

		-- Those markers can only be dug when all adjacent TS's are set
		-- as EOI.
		local meta = minetest.get_meta(pos)
		local tcbpts = meta:get_string("tcb_pos")
		if tcbpts ~= "" then
			if not minetest.check_player_privs(pname, "interlocking") then
				minetest.chat_send_player(pname, "Insufficient privileges to use this!")
				return
			end			
			local tcbpos = minetest.string_to_pos(tcbpts)
			local tcb = ildb.get_tcb(tcbpos)
			if not tcb then return true end
			for connid=1,2 do
				if tcb[connid].signal then
					minetest.chat_send_player(pname, "Can't remove TCB: Both sides must have no signal assigned!")
					return false
				end
			end
		end	
		return true
	end,
	after_dig_node = function(pos, oldnode, oldmetadata, player)
		if not oldmetadata or not oldmetadata.fields then return end
		local pname = player:get_player_name()
		local tcbpts = oldmetadata.fields.tcb_pos
		if tcbpts and tcbpts ~= "" then
			local tcbpos = minetest.string_to_pos(tcbpts)
			ildb.remove_tcb_at(tcbpos, pname)
		end
	end,
})


-- Crafting

-- set some fallbacks
local tcb_core = "default:mese_crystal"
local tcb_secondary = "default:mese_crystal_fragment"

--alternative recipe items
--core
if minetest.get_modpath("basic_materials") then
	tcb_core = "basic_materials:ic"
elseif minetest.get_modpath("technic") then
	tcb_core = "technic:control_logic_unit"
end
--print("TCB Core: "..tcb_core)
--secondary
if minetest.get_modpath("mesecons") then
	tcb_secondary = 'mesecons:wire_00000000_off'
end
--print("TCB Secondary: "..tcb_secondary)

minetest.register_craft({
	output = 'advtrains_interlocking:tcb_node 4',
	recipe = {
		{tcb_secondary,tcb_core,tcb_secondary},
		{'advtrains:dtrack_placer','','advtrains:dtrack_placer'}
	},
	--actually use track in the tcb recipe
	replacements = {
		{"advtrains:dtrack_placer","advtrains:dtrack_placer"},
		{"advtrains:dtrack_placer","advtrains:dtrack_placer"},
	}
})

--nil the temp crafting variables
tcb_core= nil
tcb_secondary = nil

minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	-- TCB assignment
	local tcbnpos = players_assign_tcb[pname]
	if tcbnpos then
		if vector.distance(pos, tcbnpos)<=20 then
			local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
			if node_ok and #conns == 2 then
				-- if there is already a tcb here, reassign it
				if ildb.get_tcb(pos) then
					minetest.chat_send_player(pname, "Configuring TCB: Already existed at this position, it is now linked to this TCB marker")
				else
					ildb.create_tcb_at(pos, pname)
				end

				local meta = minetest.get_meta(tcbnpos)
				meta:set_string("tcb_pos", minetest.pos_to_string(pos))
				meta:set_string("infotext", "TCB assigned to "..minetest.pos_to_string(pos))
				minetest.chat_send_player(pname, "Configuring TCB: Successfully configured TCB")
				advtrains.interlocking.show_tcb_marker(pos)
			else
				minetest.chat_send_player(pname, "Configuring TCB: This is not a normal two-connection rail! Aborted.")
			end
		else
			minetest.chat_send_player(pname, "Configuring TCB: Node is too far away. Aborted.")
		end
		players_assign_tcb[pname] = nil
	end
	
	-- Signal assignment
	local sigd = players_assign_signal[pname]
	if sigd then
		if vector.distance(pos, sigd.p)<=50 then
			local is_signal = minetest.get_item_group(node.name, "advtrains_signal") >= 2
			if is_signal then
				local ndef = minetest.registered_nodes[node.name]
				if ndef and ndef.advtrains and ndef.advtrains.apply_aspect then
					local tcbs = ildb.get_tcbs(sigd)
					if tcbs then
						tcbs.signal = pos
						if not tcbs.routes then
							tcbs.routes = {}
						end
						ildb.set_sigd_for_signal(pos, sigd)
						minetest.chat_send_player(pname, "Configuring TCB: Successfully assigned signal.")
						advtrains.interlocking.show_ip_form(pos, pname, true)
					else
						minetest.chat_send_player(pname, "Configuring TCB: Internal error, TCBS doesn't exist. Aborted.")
					end
				else
					minetest.chat_send_player(pname, "Configuring TCB: Cannot use static signals for routesetting. Aborted.")
				end
			else
				minetest.chat_send_player(pname, "Configuring TCB: Not a compatible signal. Aborted.")
			end
		else
			minetest.chat_send_player(pname, "Configuring TCB: Node is too far away. Aborted.")
		end
		players_assign_signal[pname] = nil
	end
end)

-- TCB Form

local function mktcbformspec(pos, side, tcbs, offset, pname)
	local form = ""
	local btnpref = side==1 and "A" or "B"
	local ts
	-- ensure that mapping and xlink are up to date
	ildb.tcbs_ensure_ts_ref_exists({p=pos, s=side, tcbs=tcbs})
	ildb.validate_tcb_xlink({p=pos, s=side, tcbs=tcbs})
	-- Note: repair operations may have been triggered by this
	if tcbs.ts_id then
		ts = ildb.get_ts(tcbs.ts_id)
	end
	if ts then
		form = form.."label[0.5,"..offset..";Side "..btnpref..": "..minetest.formspec_escape(ts.name or tcbs.ts_id).."]"
		form = form.."button[0.5,"..(offset+0.5)..";5,1;"..btnpref.."_gotots;Show track section]"
	else
		tcbs.ts_id = nil
		form = form.."label[0.5,"..offset..";Side "..btnpref..": ".."End of interlocking]"
		form = form.."button[0.5,"..(offset+0.5)..";5,1;"..btnpref.."_makeil;Create Interlocked Track Section]"
	end
	-- xlink
	if tcbs.xlink then
		form = form.."label[0.5,"..(offset+1.5)..";Link:"..ildb.sigd_to_string(tcbs.xlink).."]"
		form = form.."button[4.5,"..(offset+1.5)..";1,1;"..btnpref.."_xlinkdel;X]"
	else
		if players_assign_xlink[pname] then
			form = form.."button[0.5,"..(offset+1.5)..";4,1;"..btnpref.."_xlinklink;Link "..ildb.sigd_to_string(players_assign_xlink[pname]).."]"
			form = form.."button[4.5,"..(offset+1.5)..";1,1;"..btnpref.."_xlinkabrt;X]"
		else
			form = form.."label[0.5,"..(offset+1.5)..";No Link]"
			form = form.."button[4.5,"..(offset+1.5)..";1,1;"..btnpref.."_xlinkadd;+]"
		end
	end
	if tcbs.signal then
		form = form.."button[0.5,"..(offset+2.5)..";5,1;"..btnpref.."_sigdia;Signalling]"	
	else
		form = form.."button[0.5,"..(offset+2.5)..";5,1;"..btnpref.."_asnsig;Assign a signal]"
	end
	return form
end


function advtrains.interlocking.show_tcb_form(pos, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	local tcb = ildb.get_tcb(pos)
	if not tcb then return end
	
	local form = "size[6,9] label[0.5,0.5;Track Circuit Break Configuration]"
	form = form .. mktcbformspec(pos, 1, tcb[1], 1, pname)
	form = form .. mktcbformspec(pos, 2, tcb[2], 5, pname)
	
	minetest.show_formspec(pname, "at_il_tcbconfig_"..minetest.pos_to_string(pos), form)
	advtrains.interlocking.show_tcb_marker(pos)
end

--helper: length of nil table is 0
local function nlen(t)
	if not t then return 0 end
	return #t
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local pts = string.match(formname, "^at_il_tcbconfig_(.+)$")
	local pos
	if pts then
		pos = minetest.string_to_pos(pts)
	end
	if pos and not fields.quit then
		local tcb = ildb.get_tcb(pos)
		if not tcb then return end
		local f_gotots = {fields.A_gotots, fields.B_gotots}
		local f_makeil = {fields.A_makeil, fields.B_makeil}
		local f_asnsig = {fields.A_asnsig, fields.B_asnsig}
		local f_sigdia = {fields.A_sigdia, fields.B_sigdia}
		local f_xlinkadd = {fields.A_xlinkadd, fields.B_xlinkadd}
		local f_xlinkdel = {fields.A_xlinkdel, fields.B_xlinkdel}
		local f_xlinklink = {fields.A_xlinklink, fields.B_xlinklink}
		local f_xlinkabrt = {fields.A_xlinkabrt, fields.B_xlinkabrt}
		
		for connid=1,2 do
			local tcbs = tcb[connid]
			if tcbs.ts_id then
				if f_gotots[connid] then
					advtrains.interlocking.show_ts_form(tcbs.ts_id, pname)
					return
				end
			else
				if f_makeil[connid] then
					if not tcbs.ts_id then
						ildb.create_ts_from_tcbs({p=pos, s=connid})
					end
				end
			end
			if tcbs.xlink then
				if f_xlinkdel[connid] then
					ildb.remove_tcb_xlink({p=pos, s=connid})
				end
			else
				local osigd = players_assign_xlink[pname]
				if osigd then
					if f_xlinklink[connid] then
						ildb.add_tcb_xlink({p=pos, s=connid}, osigd)
						players_assign_xlink[pname] = nil
					elseif f_xlinkabrt[connid] then
						players_assign_xlink[pname] = nil
					end
				else
					if f_xlinkadd[connid] then
						players_assign_xlink[pname] = {p=pos, s=connid}
						minetest.chat_send_player(pname, "TCB Link: Select linked TCB now!")
						minetest.close_formspec(pname, formname)
						return -- to not reopen form
					end
				end
			end
			if f_asnsig[connid] and not tcbs.signal then
				minetest.chat_send_player(pname, "Configuring TCB: Please punch the signal to assign.")
				players_assign_signal[pname] = {p=pos, s=connid}
				minetest.close_formspec(pname, formname)
				return
			end
			if f_sigdia[connid] and tcbs.signal then
				advtrains.interlocking.show_signalling_form({p=pos, s=connid}, pname)
				return
			end

		end
		advtrains.interlocking.show_tcb_form(pos, pname)
	end

end)



-- TS Formspec

function advtrains.interlocking.show_ts_form(ts_id, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	local ts = ildb.get_ts(ts_id)
	if not ts_id then return end
	
	local form = "size[10,10]label[0.5,0.5;Track Section Detail - "..ts_id.."]"
	form = form.."field[0.8,2;5.2,1;name;Section name;"..minetest.formspec_escape(ts.name or "").."]"
	form = form.."button[5.5,1.7;1,1;setname;Set]"
	local hint
	
	local strtab = {}
	for idx, sigd in ipairs(ts.tc_breaks) do
		strtab[#strtab+1] = minetest.formspec_escape(sigd_to_string(sigd))
		advtrains.interlocking.show_tcb_marker(sigd.p)
	end
	
	form = form.."textlist[0.5,3;5,3;tcblist;"..table.concat(strtab, ",").."]"
	
	if ildb.may_modify_ts(ts) then
		form = form.."button[5.5,4;4,1;remove;Remove Section]"
		form = form.."tooltip[dissolve;This will remove the track section and set all its end points to End Of Interlocking]"
	else
		hint=3
	end
	
	if ts.route then
		form = form.."label[0.5,6.1;Route is set: "..ts.route.rsn.."]"
	elseif ts.route_post then
		form = form.."label[0.5,6.1;Section holds "..#(ts.route_post.lcks or {}).." route locks.]"
	end
	-- occupying trains
	if ts.trains and #ts.trains>0 then
		form = form.."label[0.5,7.1;Trains on this section:]"
		form = form.."textlist[0.5,7.7;3,2;trnlist;"..table.concat(ts.trains, ",").."]"
	else
		form = form.."label[0.5,7.1;No trains on this section.]"
	end
	
	form = form.."button[5.5,7;4,1;reset;Reset section state]"

	if hint == 3 then
		form = form.."label[0.5,0.75;You cannot modify track sections when a route is set or a train is on the section.]"
		--form = form.."label[0.5,1;Trying to unlink a TCB directly connected to this track will not work.]"
	end
	
	minetest.show_formspec(pname, "at_il_tsconfig_"..ts_id, form)
	
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	-- independent of the formspec, clear this whenever some formspec event happens
	
	local ts_id = string.match(formname, "^at_il_tsconfig_(.+)$")
	if ts_id and not fields.quit then
		local ts = ildb.get_ts(ts_id)
		if not ts then return end
		
		if ildb.may_modify_ts(ts) then
			if fields.remove then
				ildb.remove_ts(ts_id)
				minetest.close_formspec(pname, formname)
				return
			end
		end
		
		if fields.setname then
			ts.name = fields.name
			if ts.name == "" then
				ts.name = nil
			end
		end
		
		if fields.reset then
			-- User requested resetting the section
			-- Show him what this means...
			local form = "size[7,5]label[0.5,0.5;Reset track section]"
			form = form.."label[0.5,1;This will clear the list of trains\nand the routesetting status of this section.\nAre you sure?]"
			form = form.."button_exit[0.5,2.5;  5,1;reset;Yes]"
			form = form.."button_exit[0.5,3.5;  5,1;cancel;Cancel]"
			minetest.show_formspec(pname, "at_il_tsreset_"..ts_id, form)
			return
		end
		
		advtrains.interlocking.show_ts_form(ts_id, pname, sel_tcb)
		return
	end
	
	ts_id = string.match(formname, "^at_il_tsreset_(.+)$")
	if ts_id and fields.reset then
		local ts = ildb.get_ts(ts_id)
		if not ts then return end
		ts.trains = {}
		if ts.route_post then
			advtrains.interlocking.route.free_route_locks(ts_id, ts.route_post.locks)
		end
		ts.route_post = nil
		ts.route = nil
		for _, sigd in ipairs(ts.tc_breaks) do
			local tcbs = ildb.get_tcbs(sigd)
			advtrains.interlocking.signal.update_route_aspect(tcbs)
		end
		minetest.chat_send_player(pname, "Reset track section "..ts_id.."!")
	end
end)

-- TCB marker entities

-- table with objectRefs
local markerent = {}

minetest.register_entity("advtrains_interlocking:tcbmarker", {
	visual = "mesh",
	mesh = "trackplane.b3d",
	textures = {"at_il_tcb_marker.png"},
	collisionbox = {-1,-0.5,-1, 1,-0.4,1},
	visual_size = {x=10, y=10},
	on_punch = function(self)
		self.object:remove()
	end,
	on_rightclick = function(self, player)
		if self.tcbpos and player then
			advtrains.interlocking.show_tcb_form(self.tcbpos, player:get_player_name())
		end
	end,
	get_staticdata = function() return "STATIC" end,
	on_activate = function(self, sdata) if sdata=="STATIC" then self.object:remove() end end,
	static_save = false,
})

function advtrains.interlocking.show_tcb_marker(pos)
	--atdebug("showing tcb marker",pos)
	local tcb = ildb.get_tcb(pos)
	if not tcb then return end
	local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
	if not node_ok then return end
	local yaw = advtrains.conn_angle_median(conns[2].c, conns[1].c)
	
	local itex = {}
	for connid=1,2 do
		local tcbs = tcb[connid]
		local ts
		if tcbs.ts_id then
			ts = ildb.get_ts(tcbs.ts_id)
		end
		if ts then
			itex[connid] = ts.name or tcbs.ts_id or "???"
		else
			itex[connid] = "--EOI--"
		end
	end
	
	local pts = advtrains.roundfloorpts(pos)
	if markerent[pts] then
		markerent[pts]:remove()
	end
	
	local obj = minetest.add_entity(pos, "advtrains_interlocking:tcbmarker")
	if not obj then return end
	obj:set_yaw(yaw)
	obj:set_properties({
		infotext = "A = "..itex[1].."\nB = "..itex[2]
	})
	local le = obj:get_luaentity()
	if le then le.tcbpos = pos end
	
	markerent[pts] = obj
end

function advtrains.interlocking.remove_tcb_marker(pos)
	local pts = advtrains.roundfloorpts(pos)
	if markerent[pts] then
		markerent[pts]:remove()
	end
	markerent[pts] = nil
end

local ts_showparticles_callback = function(pos, connid, bconnid)
	minetest.add_particle({
		pos = pos,
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = 10,
		size = 7,
		vertical = true,
		texture = "at_il_ts_highlight_particle.png",
		glow = 6,
	})
end

-- Spawns particles to highlight the clicked track section
-- TODO: Adapt behavior to not dumb-walk anymore
function advtrains.interlocking.highlight_track_section(pos)
	local all_tcbs = ildb.get_all_tcbs_adjacent(pos, nil, ts_showparticles_callback)
	for _,sigd in ipairs(all_tcbs) do
		advtrains.interlocking.show_tcb_marker(sigd.p)
	end
end

-- Signalling formspec - set routes a.s.o

-- textlist selection temporary storage
local sig_pselidx = {}
-- Players having a signalling form open
local p_open_sig_form = {}

function advtrains.interlocking.show_signalling_form(sigd, pname, sel_rte, called_from_form_update)
	if not minetest.check_player_privs(pname, "train_operator") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	local hasprivs = minetest.check_player_privs(pname, "interlocking")
	local tcbs = ildb.get_tcbs(sigd)
	
	if not tcbs.signal then return end
	if not tcbs.routes then tcbs.routes = {} end
	
	local form = "size[7,10.25]label[0.5,0.5;Signal at "..minetest.pos_to_string(sigd.p).."]"
	form = form.."field[0.8,1.5;5.2,1;name;Signal name;"..minetest.formspec_escape(tcbs.signal_name or "").."]"
	form = form.."button[5.5,1.2;1,1;setname;Set]"
	
	if tcbs.routeset then
		local rte = tcbs.routes[tcbs.routeset]
		if not rte then
			atwarn("Unknown route set from signal!")
			tcbs.routeset = nil
			return
		end
		form = form.."label[0.5,2.5;A route is requested from this signal:]"
		form = form.."label[0.5,3.0;"..minetest.formspec_escape(rte.name).."]"
		if tcbs.route_committed then
			form = form.."label[0.5,3.5;Route has been set.]"
		else
			form = form.."label[0.5,3.5;Waiting for route to be set...]"
			if tcbs.route_rsn then
				form = form.."label[0.5,4;"..minetest.formspec_escape(tcbs.route_rsn).."]"
			end
		end
		if not tcbs.route_auto then
			form = form.."button[0.5,7;  5,1;auto;Enable Automatic Working]"
		else
			form = form.."label[0.5,7  ;Automatic Working is active.]"
			form = form.."label[0.5,7.3;Route is re-set when a train passed.]"
			form = form.."button[0.5,7.7;  5,1;noauto;Disable Automatic Working]"
		end
		
		form = form.."button[0.5,6;  5,1;cancelroute;Cancel Route]"
	else
		if not tcbs.route_origin then
			local strtab = {}
			for idx, route in ipairs(tcbs.routes) do
				local clr = ""
				if route.ars then
					clr = "#FF5555"
					if route.ars.default then
						clr = "#55FF55"
					end
				end
				strtab[#strtab+1] = clr .. minetest.formspec_escape(route.name)
			end
			form = form.."label[0.5,2.5;Routes:]"
			form = form.."textlist[0.5,3;5,3;rtelist;"..table.concat(strtab, ",").."]"
			if sel_rte then
				form = form.."button[0.5,6;  5,1;setroute;Set Route]"
				form = form.."button[0.5,7;2,1;dsproute;Show]"
				if hasprivs then
					form = form.."button[3.5,7;2,1;editroute;Edit]"
				end
			else
				if tcbs.ars_disabled then
					form = form.."label[0.5,6  ;NOTE: ARS is disabled.]"
					form = form.."label[0.5,6.5;Routes are not automatically set.]"
				end
			end
			if hasprivs then
				form = form.."button[0.5,8;2.5,1;smartroute;Smart Route]"
				form = form.."button[  3,8;2.5,1;newroute;New (Manual)]"
				form = form..string.format("checkbox[0.5,8.75;ars;Automatic routesetting;%s]", not tcbs.ars_disabled)
			end
		elseif sigd_equal(tcbs.route_origin, sigd) then
			-- something has gone wrong: tcbs.routeset should have been set...
			form = form.."label[0.5,2.5;Inconsistent state: route_origin is same TCBS but no route set. Try again.]"
			ilrs.cancel_route_from(sigd)
		else
			form = form.."label[0.5,2.5;Route is set over this signal by:\n"..sigd_to_string(tcbs.route_origin).."]"
			form = form.."label[0.5,4;Wait for this route to be cancelled in order to do anything here.]"
		end
	end	
	sig_pselidx[pname] = sel_rte
	minetest.show_formspec(pname, "at_il_signalling_"..minetest.pos_to_string(sigd.p).."_"..sigd.s, form)
	p_open_sig_form[pname] = sigd
	
	-- always a good idea to update the signal aspect
	if not called_from_form_update then
	-- FIX prevent a callback loop
		advtrains.interlocking.signal.update_route_aspect(tcbs)
	end
end

function advtrains.interlocking.update_player_forms(sigd)
	for pname, tsigd in pairs(p_open_sig_form) do
		if advtrains.interlocking.sigd_equal(sigd, tsigd) then
			advtrains.interlocking.show_signalling_form(sigd, pname, nil)
		end
	end
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "train_operator") then
		return
	end
	local hasprivs = minetest.check_player_privs(pname, "interlocking")
	
	-- independent of the formspec, clear this whenever some formspec event happens
	local tpsi = sig_pselidx[pname]
	sig_pselidx[pname] = nil
	p_open_sig_form[pname] = nil
	
	local pts, connids = string.match(formname, "^at_il_signalling_([^_]+)_(%d)$")
	local pos, connid
	if pts then
		pos = minetest.string_to_pos(pts)
		connid = tonumber(connids)
		if not connid or connid<1 or connid>2 then return end
	end
	if pos and connid then
		local sigd = {p=pos, s=connid}
		local tcbs = ildb.get_tcbs(sigd)
		if not tcbs then return end

		if fields.quit then
			-- form quit: disable temporary ARS ignore
			tcbs.ars_ignore_next = nil
			return
		end

		local sel_rte
		if fields.rtelist then
			local tev = minetest.explode_textlist_event(fields.rtelist)
			sel_rte = tev.index
		elseif tpsi then
			sel_rte = tpsi
		end
		if fields.setname and fields.name and hasprivs then
			if fields.name == "" then
				tcbs.signal_name = nil -- do not save a signal name if it isnt used (equivalent to track sections)
			else
				tcbs.signal_name = fields.name
			end
		end
		if tcbs.routeset and fields.cancelroute then
			if tcbs.routes[tcbs.routeset] and tcbs.routes[tcbs.routeset].ars then
				tcbs.ars_ignore_next = true
			end
			-- if route committed, cancel route ts info
			ilrs.update_route(sigd, tcbs, nil, true)
		end
		if not tcbs.routeset then
			if fields.newroute and hasprivs then
				advtrains.interlocking.init_route_prog(pname, sigd)
				minetest.close_formspec(pname, formname)
				tcbs.ars_ignore_next = nil
				return
			end
			if fields.smartroute and hasprivs then
				advtrains.interlocking.smartroute.init(pname, sigd)
				minetest.close_formspec(pname, formname)
				tcbs.ars_ignore_next = nil
				return
			end
			if sel_rte and tcbs.routes[sel_rte] then
				if fields.setroute then
					ilrs.update_route(sigd, tcbs, sel_rte)
				end
				if fields.dsproute then
					local t = os.clock()
					advtrains.interlocking.visualize_route(sigd, tcbs.routes[sel_rte], "disp_"..t)
					minetest.after(10, function() advtrains.interlocking.clear_visu_context("disp_"..t) end)
				end
				if fields.editroute and hasprivs then
					advtrains.interlocking.show_route_edit_form(pname, sigd, sel_rte)
					--local rte = tcbs.routes[sel_rte]
					--minetest.show_formspec(pname, formname.."_renroute_"..sel_rte, "field[name;Enter new route name;"..rte.name.."]")
					return
				end
			end
		end
		
		if fields.ars then
			tcbs.ars_disabled = not minetest.is_yes(fields.ars)
		end
		
		if fields.auto then
			tcbs.route_auto = true
		end
		if fields.noauto then
			tcbs.route_auto = false
		end
		
		advtrains.interlocking.show_signalling_form(sigd, pname, sel_rte, true)
		return
	end
	
	
	if not hasprivs then return end
	-- rename route
	local rind, rte_id
	pts, connids, rind = string.match(formname, "^at_il_signalling_([^_]+)_(%d)_renroute_(%d+)$")
	if pts then
		pos = minetest.string_to_pos(pts)
		connid = tonumber(connids)
		rte_id = tonumber(rind)
		if not connid or connid<1 or connid>2 then return end
	end
	if pos and connid and rind and fields.name then
		local sigd = {p=pos, s=connid}
		local tcbs = ildb.get_tcbs(sigd)
		if tcbs.routes[rte_id] then
			tcbs.routes[rte_id].name = fields.name
			advtrains.interlocking.show_signalling_form(sigd, pname)
		end
	end
end)
