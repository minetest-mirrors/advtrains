-- route_ui.lua
-- User interface for showing and editing routes

local atil = advtrains.interlocking
local ildb = atil.db
local F = advtrains.formspec

-- TODO duplicate
local lntrans = { "A", "B" }
local function sigd_to_string(sigd)
	return minetest.pos_to_string(sigd.p).." / "..lntrans[sigd.s]
end



function atil.show_route_edit_form(pname, sigd, routeid)

	if not minetest.check_player_privs(pname, {train_operator=true, interlocking=true}) then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	
	local tcbs = atil.db.get_tcbs(sigd)
	if not tcbs then return end
	local route = tcbs.routes[routeid]
	if not route then return end
	
	local form = "size[9,11]label[0.5,0.2;Route overview]"
	form = form.."field[0.8,1.2;6.5,1;name;Route name;"..minetest.formspec_escape(route.name).."]"
	form = form.."button[7.0,0.9;1.5,1;setname;Set]"
	
	-- construct textlist for route information
	local tab = {}
	local function itab(t)
		tab[#tab+1] = minetest.formspec_escape(string.gsub(t, ",", " "))
	end
	itab("("..(tcbs.signal_name or "+")..") Route #"..routeid)
	
	-- this code is partially copy-pasted from routesetting.lua
	-- we start at the tc designated by signal
	local c_sigd = sigd
	local i = 1
	local c_tcbs, c_ts_id, c_ts, c_rseg, c_lckp
	while c_sigd and i<=#route do
		c_tcbs = ildb.get_tcbs(c_sigd)
		if not c_tcbs then
			itab("-!- No TCBS at "..sigd_to_string(c_sigd)..". Please reconfigure route!")
			break
		end
		c_ts_id = c_tcbs.ts_id
		if not c_ts_id then
			itab("-!- No track section adjacent to "..sigd_to_string(c_sigd)..". Please reconfigure route!")
			break
		end
		c_ts = ildb.get_ts(c_ts_id)
		
		c_rseg = route[i]
		c_lckp = {}
		
		itab(""..i.." "..sigd_to_string(c_sigd))
		itab("= "..(c_ts and c_ts.name or "-").." =")
		
		if c_rseg.locks then
			for pts, state in pairs(c_rseg.locks) do
				
				local pos = minetest.string_to_pos(pts)
				itab("L "..pts.." -> "..state)
				if not advtrains.is_passive(pos) then
					itab("-!- No passive component at "..pts..". Please reconfigure route!")
					break
				end
			end
		end
		-- advance
		c_sigd = c_rseg.next
		i = i + 1
	end
	if c_sigd then
		local e_tcbs = ildb.get_tcbs(c_sigd)
		local signame = "-"
		if e_tcbs and e_tcbs.signal then signame = e_tcbs.signal_name or "+" end
		itab("E "..sigd_to_string(c_sigd).." ("..signame..")")
	else
		itab("E (none)")
	end
	
	form = form.."textlist[0.5,2;3.5,3.9;rtelog;"..table.concat(tab, ",").."]"
	
	-- to the right of rtelog a signal aspect selection for the start signal
	form = form..F.label(4.5, 2, "Signal Aspect:")
	-- main aspect list
	local signalpos = tcbs.signal
	local ndef = signalpos and advtrains.ndb.get_ndef(signalpos)
	if ndef and ndef.advtrains and ndef.advtrains.main_aspects then
		local entries = { "<Default Aspect>" }
		local sel = 1
		for i, mae in ipairs(ndef.advtrains.main_aspects) do
			entries[i+1] = mae.description
			if mae.name == route.main_aspect then
				sel = i+1
			end
		end
		form = form..F.dropdown(4.5, 3.0, 4, "sa_main_aspect", entries, sel, true)
		-- checkbox for assign distant signal
		form = form..string.format("checkbox[4.5,4.0;sa_distant;Announce distant signal;%s]", route.assign_dst)
	end
	
	form = form.."button[0.5,6;1,1;prev;<<<]"
	form = form.."button[1.5,6;1,1;back;"..routeid.."/"..#tcbs.routes.."]"
	form = form.."button[2.5,6;1,1;next;>>>]"
	
	
	if route.smartroute_generated then
		form = form.."button[3.5,6;2,1;noautogen;Clr Autogen]"
	end
	form = form.."button[5.5,6;3,1;delete;Delete Route]"
	form = form.."button[0.5,7;3,1;back;Back to signal]"
	form = form.."button[3.5,7;2,1;clone;Clone Route]"
	form = form.."button[5.5,7;3,1;newfrom;New From Route]"
	
	--atdebug(route.ars)
	form = form.."style[ars;font=mono]"
	form = form.."textarea[0.8,8.3;5,3;ars;ARS Rule List;"..atil.ars_to_text(route.ars).."]"
	form = form.."button[5.5,8.23;3,1;savears;Save ARS List]"
	
	minetest.show_formspec(pname, "at_il_routeedit_"..minetest.pos_to_string(sigd.p).."_"..sigd.s.."_"..routeid, form)

end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, {train_operator=true, interlocking=true}) then
		return
	end
	
	local pts, connids, routeids = string.match(formname, "^at_il_routeedit_([^_]+)_(%d)_(%d+)$")
	local pos, connid, routeid
	if pts then
		pos = minetest.string_to_pos(pts)
		connid = tonumber(connids)
		routeid = tonumber(routeids)
		if not connid or connid<1 or connid>2 then return end
		if not routeid then return end
	end
	if pos and connid and routeid and not fields.quit then
		local sigd = {p=pos, s=connid}
		local tcbs = ildb.get_tcbs(sigd)
		if not tcbs then return end
		local route = tcbs.routes[routeid]
		if not route then return end
		
		if fields.prev then
			atil.show_route_edit_form(pname, sigd, routeid - 1)
			return
		end
		if fields.next then
			atil.show_route_edit_form(pname, sigd, routeid + 1)
			return
		end
		
		if fields.setname and fields.name then
			route.name = fields.name
		end
		
		if fields.sa_main_aspect then
			local idx = tonumber(fields.sa_main_aspect)
			route.main_aspect = nil
			if idx > 1 then
				local signalpos = tcbs.signal
				local ndef = signalpos and advtrains.ndb.get_ndef(signalpos)
				if ndef and ndef.advtrains and ndef.advtrains.main_aspects then
					route.main_aspect = ndef.advtrains.main_aspects[idx - 1].name
				end
			end
		end
		if fields.sa_distant then
			route.assign_dst = minetest.is_yes(fields.sa_distant)
		end
		
		if fields.noautogen then
			route.smartroute_generated = nil
		end
		
		if fields.delete then
			-- if something set the route in the meantime, make sure this doesn't break.
			atil.route.update_route(sigd, tcbs, nil, true)
			table.remove(tcbs.routes, routeid)
			advtrains.interlocking.show_signalling_form(sigd, pname)
		end
		
		if fields.clone then
			-- if something set the route in the meantime, make sure this doesn't break.
			atil.route.update_route(sigd, tcbs, nil, true)
			local rcopy = table.copy(route)
			rcopy.name = route.name.."_copy"
			rcopy.smartroute_generated = nil
			table.insert(tcbs.routes, routeid+1, rcopy)
			advtrains.interlocking.show_signalling_form(sigd, pname)
		end

		if fields.newfrom then
			advtrains.interlocking.init_route_prog(pname, sigd, route)
			minetest.close_formspec(pname, formname)
			tcbs.ars_ignore_next = nil
			return
		end
		
		if fields.ars and fields.savears then
			route.ars = atil.text_to_ars(fields.ars)
			--atdebug(route.ars)
		end
		
		if fields.back then
			advtrains.interlocking.show_signalling_form(sigd, pname)
		end
		
	end
end)
