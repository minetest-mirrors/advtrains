-- stoprail.lua
-- adds "stop rail". Recognized by lzb. (part of behavior is implemented there)

-- Get current translator
local S = advtrains.lines.translate

local rwt = assert(advtrains.lines.rwt)

local function to_int(n)
	--- Disallow floating-point numbers
	local k = tonumber(n)
	if k then
		return math.floor(k)
	end
end

local function updatemeta(pos)
	local meta = minetest.get_meta(pos)
	local pe = advtrains.encode_pos(pos)
	local stdata = advtrains.lines.stops[pe]
	if not stdata then
		meta:set_string("infotext", "Error")
		return
	end
	local stn = advtrains.lines.stations[stdata.stn]
	local stn_viewname = stn and stn.name or "-"
	
	meta:set_string("infotext", S("Stn. @1 (@2) T. @3", stn_viewname, stdata.stn or "", stdata.track or ""))
end

local door_dropdown = {L=1, R=2, C=3}
--local door_dropdown_rev = {Right="R", Left="L", Closed="C"} -- Code review : why are the value in an order different than the one in the dropdown box ?
local door_dropdown_code = {"L", "R", "C"} -- switch to numerical index of selection : for conversion of the numerical index in the opening side selection dropdown box to the internal codification

local function get_stn_dropdown(stn, player_name)
	local stations = advtrains.lines.load_stations_for_formspec()
	local selected_index
	local result = {"dropdown[0.5,1.3;6.7,0.8;stn;"..S("(unassigned)")}
	local right_mark
	for i, st in ipairs(stations) do
		if player_name ~= nil and player_name ~= st.owner then
			right_mark = S("(foreign)")
		else
			right_mark = ""
		end
		table.insert(result, ","..right_mark..minetest.formspec_escape(st.stn.."  |  "..st.name))
		if st.stn == stn then
			selected_index = i + 1
		end
	end
	table.insert(result, ";"..(selected_index or "1")..";true]")
	return table.concat(result)
end

--[[
formspec_version[6]
size[12,12.3]
label[0.5,0.5;Station/Stop Track -486\,3\,367]
style[ars,arr_action,dep_action;font=mono]
label[0.5,1.1;Station Code | Station Name]
dropdown[0.5,1.3;6.7,0.8;stn;(nepřiřazeno),Brp  |  Brpigcelerefern,Drp  |  Drpa,Hik  |  Hikieg,Kek  |  Kekonen,Log  |  Logremlake,ME  |  Memironpa,Orgp  |  Orgpen,Qrl  |  Quriblake,Shi  |  Shipcotio,Shr  |  Shiponrumott,Van  |  Vannde;8;true]
field[0.5,2.6;1.5,0.8;track;Track;2W]
tooltip[track;Track number\, for informational purposes]
button[3.5,2.3;3.7,1.1;editstn;Station Editor]
textarea[7.5,1.3;4,2.1;selector_ars;Position for (ARS);]
tooltip[selector_ars;Only trains matching these ARS rules will consider this stop rail as suitable timing point/stop position. Affects both timetabled and non-timetabled trains. Example: define a stop position for long trains (TL 30) and another for short trains (TL 0-30).]
tooltip[ars;Non-timetabled trains matching these ARS rules will stop at this position. Note: Train must also match the 'Position For' filter!]
button[7.5,1.3;4,0.8;selector_ars_enable;Selector for stop position...]
tooltip[selector_ars_enable;Use when multiple stop rails are located in the same track of a station. Allows to select a suitable stop position depending on the class of train.]
tooltip[ars;Non-timetabled trains matching these ARS rules will stop at this position. Trains under timetable will use the timetable's settings.]
textarea[0.5,4.3;4,1.3;ars;Stopping trains (ARS);]
field[0.5,6.1;1.5,0.8;wait;Stop Time;10]
tooltip[wait;Train will remain stopped with open doors for at least this time before departure is attempted.]
label[2.4,5.9;Door Side]
dropdown[2.4,6.1;1.9,0.8;doors;left,right,closed;2;true]
tooltip[doors;Select if and on which side the train will open its doors once stopped]
checkbox[0.5,7.3;reverse;Reverse train;false]
tooltip[reverse;Train will depart in the direction from where it arrived]
checkbox[0.5,7.9;kick;Kick out passengers;false]
checkbox[0.5,8.5;arskeepen;Keep ARS enabled;false]
tooltip[arskeepen;Do not disable ARS on approaching. Signals behind the stop rail already set ARS routes when the train arrives\, not just before departure. (currently not implemented)]
textarea[0.5,9.3;5.3,1.5;arr_action;Arrival Actions;<not yet implemented>]
tooltip[arr_action;List of actions to perform on arrival (currently not implemented\, later will allow actions such as setting line\, RC and displays)]
field[9.2,4.3;1.1,0.8;speed;Speed;M]
tooltip[speed;Speed that the train sets when departing. Set 'M' for maximum speed.]
label[6.2,4.1;Departure Mode]
dropdown[6.2,4.3;2.5,0.8;depmode;Normal,Interval,Begin Timetable;2;true]
tooltip[depmode;Select the time for departure:
Normal: depart immediately after the stop time elapsed
Interval: depart at the next time position set by interval and offset
Begin Timetable: The train gets the given timetable assigned and departs according to its settings (currently not implemented)]
field[6.2,5.6;1.8,0.8;interval;Interval:;60]
tooltip[interval;The interval / time distance between departures in seconds. E.g. every two minutes -> set interval = 120]
field[8.2,5.6;1.8,0.8;ioffset;Offset:;0]
tooltip[ioffset;The offset of departures from time 0:00 in seconds. E.g. interval 120 offset 60 -> departure at every odd minute]
checkbox[6.2,8.5;keepopen;Keep doors open;false]
tooltip[keepopen;Do not close the doors when departing\, if they are open]
checkbox[6.2,7.9;waitsig;Wait for signal to clear;true]
tooltip[waitsig;Do not depart immediately\, instead first enable ARS and wait until the next signal ahead clears (ATC G command) before closing the doors and departing.]
textarea[6.2,9.3;5.3,1.5;dep_action;Departure Actions;<not yet implemented>]
tooltip[dep_action;List of actions to perform on departure (currently not implemented\, later will allow actions such as setting line\, RC and displays)]
button_exit[0.5,11.2;11,0.8;save;Save]
box[0.5,3.6;11,0.1;#dddddd]
dropdown[6.2,6.6;3.8,0.8;linevar;asdf,dsdf;1;true]
]]
-- editor: https://luk3yx.gitlab.io/minetest-formspec-editor/
local depmode_to_dropdown = { normal=1, interval=2, ttbegin=3 }
local dropdown_to_depmode = { "normal", "interval", "ttbegin" }

local player_to_stn_override = {}

local function show_stoprailform(pos, player)
	local pe = advtrains.encode_pos(pos)
	local pname = player:get_player_name()
	if minetest.is_protected(pos, pname) then
		minetest.chat_send_player(pname, S("You are not allowed to configure this track."))
		return
	end
	
	local stdata = advtrains.lines.stops[pe]
	if not stdata then
		advtrains.lines.stops[pe] = {
					stn="", track="", doors="R", wait=10, ars={default=true}, speed="M"
				}
		stdata = advtrains.lines.stops[pe]
	end
	
	local stn = advtrains.lines.stations[stdata.stn]
	local stnname = stn and stn.name or ""
	if not stdata.ddelay then
		stdata.ddelay = 1
	end
	if not stdata.speed then
		stdata.speed = "M"
	end
	
	local item_name = (minetest.registered_items["advtrains_line_automation:dtrack_stop_placer"] or {}).description or ""
	local pname_unless_admin
	if not minetest.check_player_privs(pname, "train_admin") then
		pname_unless_admin = pname
	end
	local formspec = "formspec_version[6]"..
		"size[12,12.3]"..
		"label[0.5,0.5;"..minetest.formspec_escape(string.format("%s %d,%d,%d", item_name, pos.x, pos.y, pos.z)).."]"..
		"style[ars,selector_ars,arr_action,dep_action;font=mono]"..
		"label[0.5,1.1;"..S("Station Code").." | "..S("Station Name").."]"..
		get_stn_dropdown(player_to_stn_override[pname] or stdata.stn, pname_unless_admin)..
		"field[0.5,2.6;1.5,0.8;track;"..S("Track")..";"..minetest.formspec_escape(stdata.track).."]"..
		"tooltip[track;"..S("Track number, for informational purposes").."]"..
		(advtrains.lines.open_station_editor ~= nil and "button[2.3,2.6;2.5,0.8;editstn;"..S("Station Editor").."]" or "")..
		(advtrains.lines.open_line_editor ~= nil and "button[4.8,2.6;2.5,0.8;editlines;"..S("Line Editor").."]" or "")
	if stdata.selector_ars then
		formspec = formspec .. "textarea[7.5,1.3;4,2.1;selector_ars;"..S("Selector for stop pos (ARS)")..";"..advtrains.interlocking.ars_to_text(stdata.selector_ars).."]"..
		"tooltip[selector_ars;"..S("Only trains matching these ARS rules will consider this stop rail as suitable timing point/stop position.\nAffects both timetabled and non-timetabled trains.\nExample: define a stop position for long trains (TL 30) and another for short trains (TL 0-30).").."]"..
		"tooltip[ars;"..S("Non-timetabled trains matching these ARS rules will stop at this position.\nNote: Train must also match the 'Selector' filter above!").."]"
	else
		formspec = formspec .. "button[7.5,1.3;4,0.8;selector_ars_enable;"..S("Selector for stop position...").."]"..
		"tooltip[selector_ars_enable;"..S("Use when multiple stop rails are located in the same track of a station. Allows to select a suitable stop position depending on the class of train.").."]"..
		"tooltip[ars;"..S("Non-timetabled trains matching these ARS rules will stop at this position.\nTrains under timetable will use the timetable's settings.").."]"
	end	
	-- separator line
	formspec = formspec ..
		"box[0.5,3.6;11,0.1;#dddddd]"..
		--arrival
		"textarea[0.5,4.3;4,1.3;ars;"..S("Stopping trains (ARS)")..";"..advtrains.interlocking.ars_to_text(stdata.ars).."]"..
		"field[0.5,6.1;1.5,0.8;wait;"..S("Stop Time")..";"..stdata.wait.."]"..
		"tooltip[wait;"..S("Train will remain stopped with open doors for at least this time before departure is attempted.").."]"..
		"label[2.4,5.9;"..S("Door Side").."]"..
		"dropdown[2.4,6.1;1.9,0.8;doors;"..S("left")..","..S("right")..","..S("closed")..";"..door_dropdown[stdata.doors]..";true]"..
		"tooltip[doors;"..S("Select if and on which side the train will open its doors once stopped").."]"..
		"checkbox[0.5,7.3;reverse;"..S("Reverse train")..";"..(stdata.reverse and "true" or "false").."]"..
		"tooltip[reverse;"..S("Train will depart in the direction from where it arrived").."]"..
		"checkbox[0.5,7.9;kick;"..S("Kick out passengers")..";"..(stdata.kick and "true" or "false").."]"..
		"checkbox[0.5,8.5;arskeepen;"..S("Keep ARS enabled")..";"..(stdata.arskeepen and "true" or "false").."]"..
		"tooltip[arskeepen;"..S("Do not disable ARS on approaching. Signals behind the stop rail already set ARS routes when the train arrives, not just before departure. (currently not implemented)").."]"..
		"textarea[0.5,9.3;5.3,1.5;arr_action;"..S("Arrival Actions")..";<not yet implemented>]"..
		"tooltip[arr_action;"..S("List of actions to perform on arrival (currently not implemented, later will allow actions such as setting line, RC and displays)").."]"..
		-- departure
		"field[10.2,4.3;1.1,0.8;speed;"..S("Speed")..";"..minetest.formspec_escape(stdata.speed).."]"..
		"tooltip[speed;"..S("Speed that the train sets when departing. Set 'M' for maximum speed.").."]"..
		"label[6.2,4.1;"..S("Departure Mode").."]"..
		"dropdown[6.2,4.3;3.5,0.8;depmode;Normal,Interval,Begin Timetable;"..(depmode_to_dropdown[stdata.dep_mode] or 1)..";true]"..
		"tooltip[depmode;"..S("Select the time for departure:\nNormal: depart immediately after the stop time elapsed\nInterval: depart at the next time position set by interval and offset\nBegin Timetable: The train gets the given timetable assigned and departs according to its settings (currently not implemented)").."]"
	if stdata.dep_mode == "interval" then
		formspec = formspec .. "field[6.2,5.6;1.8,0.8;interval;"..S("Interval:")..";"..minetest.formspec_escape(stdata.interval or "").."]"..
		"tooltip[interval;"..S("The interval / time distance between departures in seconds. E.g. every two minutes -> set interval = 120").."]"..
		"field[8.2,5.6;1.8,0.8;ioffset;"..S("Offset:")..";"..minetest.formspec_escape(stdata.ioffset or "0").."]"..
		"tooltip[ioffset;"..S("The offset of departures from time 0:00 in seconds. E.g. interval 120 offset 60 -> departure at every odd minute").."]"
	elseif stdata.dep_mode == "ttbegin" then
		formspec = formspec .. "field[6.2,5.6;1.8,0.8;interval;"..S("Interval:")..";"..minetest.formspec_escape(stdata.interval or "").."]"..
		"tooltip[interval;"..S("The interval / time distance between departures in seconds. E.g. every two minutes -> set interval = 120").."]"..
		"field[8.2,5.6;1.8,0.8;ioffset;"..S("Offset:")..";"..minetest.formspec_escape(stdata.ioffset or "0").."]"..
		"tooltip[ioffset;"..S("The offset of departures from time 0:00 in seconds. E.g. interval 120 offset 60 -> departure at every odd minute").."]"
		-- TODO: interval and offset should be defined in the timetable, not here
		-- build list of available linevars (it is convenient that linevars are defined in the station)
		local avail_linevars = {}
		local sel_linevar = 0
		if stn and stn.linevars then
			for k,_ in pairs(stn.linevars) do
				table.insert(avail_linevars, k)
				if stdata.tt_begin_linevar==k then sel_linevar = #avail_linevars end
			end
		end
		if #avail_linevars > 0 then
			formspec = formspec .. 
			"dropdown[6.2,6.6;3.8,0.8;tt_begin_linevar;"..table.concat(avail_linevars, ",")..";"..(sel_linevar or 0)..",false]" -- this dropdown NOT using indexing!
		else
			formspec = formspec .. "label[6.2,6.6;"..S("No linevars\navailable!").."]"
		end
	end
	formspec = formspec .. "checkbox[6.2,8.5;keepopen;"..S("Keep doors open")..";"..(stdata.keepopen and "true" or "false").."]"..
		"tooltip[keepopen;"..S("Do not close the doors when departing, if they are open").."]"..
		"checkbox[6.2,7.9;waitsig;"..S("Wait for signal to clear")..";"..(stdata.waitsig and "true" or "false").."]"..
		"tooltip[waitsig;"..S("Do not depart immediately, instead first enable ARS and wait until the next signal ahead clears (ATC G command) before closing the doors and departing.").."]"..
		"textarea[6.2,9.3;5.3,1.5;dep_action;"..S("Departure Actions")..";<not yet implemented>]"..
		"tooltip[dep_action;"..S("List of actions to perform on departure (currently not implemented, later will allow actions such as setting line, RC and displays)").."]"..
		-- end
		"button_exit[0.5,11.2;11,0.8;save;"..S("Save").."]"
	--atdebug(formspec)
	minetest.show_formspec(pname, "at_lines_stop_"..pe, formspec)
end
local tmp_checkboxes = {}
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local pe = string.match(formname, "^at_lines_stop_(............)$")
	local pos = advtrains.decode_pos(pe)
	if pos then
		if minetest.is_protected(pos, pname) then
			minetest.chat_send_player(pname, S("You are not allowed to configure this track."))
			return
		end
		
		local stdata = advtrains.lines.stops[pe]
		if not tmp_checkboxes[pe] then
			tmp_checkboxes[pe] = {}
		end
		if fields.kick then			-- handle checkboxes due to MT's weird handling
			tmp_checkboxes[pe].kick = (fields.kick == "true")
		end
		if fields.reverse then
			tmp_checkboxes[pe].reverse = (fields.reverse == "true")
		end
		if fields.waitsig then
			tmp_checkboxes[pe].waitsig = (fields.waitsig == "true")
		end
		if fields.keepopen then
			tmp_checkboxes[pe].keepopen = (fields.keepopen == "true")
		end
		if fields.arskeepen then
			tmp_checkboxes[pe].arskeepen = (fields.arskeepen == "true")
		end

		if fields.stn then
			local new_index = tonumber(fields.stn)
			if new_index ~= nil then
				player_to_stn_override[pname] = new_index
			end
		end

		if fields.save or (fields.depmode and not fields.editstn and not fields.editlines) or fields.selector_ars_enable then -- must resend form when depmode dropdown is updated or the selector enable button is pressed)
			local new_index = player_to_stn_override[pname]
			if new_index ~= nil then
				if new_index == 1 then
					-- no name station
					stdata.stn = ""
					minetest.log("action", pname.." set track at "..minetest.pos_to_string(pos).." to no station.")
				else
					local stations = advtrains.lines.load_stations_for_formspec()
					local station = stations[new_index - 1]
					if station ~= nil then
						if station.owner == pname or minetest.check_player_privs(pname, "train_admin") then
							stdata.stn = station.stn
							minetest.log("action", pname.." set track at "..minetest.pos_to_string(pos).." to station '"..tostring(station.stn).."'.")
						else
							minetest.chat_send_player(pname, S("Station code '@1' does already exist and is owned by @2", station.stn, station.owner))
							show_stoprailform(pos,player)
							return
						end
					end
				end
				player_to_stn_override[pname] = nil
			end

			-- dropdowns
			if fields.doors then
				stdata.doors = door_dropdown_code[tonumber(fields.doors)] or "C" -- switch to numerical index of selection; attention : fields.doors is string typed, needed to be converted to an integer typed index in door_dropdown_code table
			end
			
			if fields.track then
				stdata.track = fields.track
			end
			if fields.wait then
				stdata.wait = to_int(fields.wait) or 10
			end
			
			if fields.ars then
				stdata.ars = advtrains.interlocking.text_to_ars(fields.ars)
			end
			
			if fields.selector_ars then
				stdata.selector_ars = advtrains.interlocking.text_to_ars(fields.selector_ars)
			elseif fields.selector_ars_enable then
				-- define selector_ars field
				stdata.selector_ars = {default=true}
			end

			stdata.ddelay = nil -- delete legacy field
			
			if fields.speed then
				stdata.speed = to_int(fields.speed) or "M"
			end
			
			if fields.depmode then
				stdata.dep_mode = dropdown_to_depmode[tonumber(fields.depmode)]
			end
			if fields.interval then
				local n = to_int(fields.interval)
				if n and 0 < n and n <= 3600 then
					stdata.interval = n
				else
					stdata.interval = 60
				end
			end
			if fields.ioffset then
				local n = to_int(fields.ioffset)
				if n and n > 0 then
					stdata.ioffset = n % stdata.interval
				else
					stdata.ioffset = 0
				end
			end
			if fields.tt_begin_linevar then
				stdata.tt_begin_linevar = fields.tt_begin_linevar
			end

			for k,v in pairs(tmp_checkboxes[pe]) do --handle checkboxes
				stdata[k] = v or nil
			end
			tmp_checkboxes[pe] = nil
			--TODO: signal
			updatemeta(pos)
			minetest.log("action", pname.." saved stoprail at "..minetest.pos_to_string(pos))
			show_stoprailform(pos, player)
		elseif fields.editstn and advtrains.lines.open_station_editor ~= nil then
			minetest.close_formspec(pname, formname)
			minetest.after(0.25, advtrains.lines.open_station_editor, player)
			return
		elseif fields.editlines and advtrains.lines.open_line_editor ~= nil then
			minetest.close_formspec(pname, formname)
			minetest.after(0.25, advtrains.lines.open_line_editor, player)
			return
		end -- if fields.save
	end -- if pos
end)

local adefunc = function(def, preset, suffix, rotation)
		return {
			after_place_node=function(pos)
				local pe = advtrains.encode_pos(pos)
				advtrains.lines.stops[pe] = {
					stn="", track="", doors="R", wait=10, waitsig = true
				}
				updatemeta(pos)
			end,
			after_dig_node=function(pos)
				local pe = advtrains.encode_pos(pos)
				advtrains.lines.stops[pe] = nil
			end,
			on_punch = function(pos, node, puncher, pointed_thing)
				updatemeta(pos)
			end,
			on_rightclick = function(pos, node, player)
				if minetest.is_player(player) then
					player_to_stn_override[player:get_player_name()] = nil
				end
				show_stoprailform(pos, player)
			end,
			advtrains = {
				on_train_approach = advtrains.lines.on_train_approach,
				on_train_enter = advtrains.lines.on_train_enter,
				on_train_leave = advtrains.lines.on_train_leave,
			},
		}
end

advtrains.station_stop_rail_additional_definition = adefunc -- HACK for tieless_tracks

minetest.register_lbm({
	label = "Update line track metadata",
	name = "advtrains_line_automation:update_metadata",
	nodenames = {
		"advtrains_line_automation:dtrack_stop_st",
		"advtrains_line_automation:dtrack_stop_st_30",
		"advtrains_line_automation:dtrack_stop_st_45",
		"advtrains_line_automation:dtrack_stop_st_60",
		"advtrains_line_automation:dtrack_stop_tieless_st",
		"advtrains_line_automation:dtrack_stop_tieless_st_30",
		"advtrains_line_automation:dtrack_stop_tieless_st_40",
		"advtrains_line_automation:dtrack_stop_tieless_st_60",
	},
	run_at_every_load = true,
	action = updatemeta,
})

if minetest.get_modpath("advtrains_train_track") ~= nil then
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains_line_automation:dtrack_stop",
		texture_prefix="advtrains_dtrack_stop",
		models_prefix="advtrains_dtrack",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_shared_stop.png",
		description=S("Station/Stop Track"),
		formats={},
		get_additional_definiton = adefunc,
	}, advtrains.trackpresets.t_30deg_straightonly)

	minetest.register_craft({
		output = "advtrains_line_automation:dtrack_stop_placer 2",
		recipe = {
			{"default:coal_lump", ""},
			{"advtrains:dtrack_placer", "advtrains:dtrack_placer"},
		},
	})
end
