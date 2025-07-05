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
	local result = {"dropdown[0.5,1.5;6.3,0.8;stn;(nepřiřazeno)"}
	local right_mark
	for i, st in ipairs(stations) do
		if player_name ~= nil and player_name ~= st.owner then
			right_mark = "(cizí) "
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
	local formspec = "formspec_version[4]"..
		"size[12,12.3]"..
		"label[0.5,0.5;"..minetest.formspec_escape(string.format("%s %d,%d,%d", item_name, pos.x, pos.y, pos.z)).."]"..
		"style[ars,arr_action,dep_action;font=mono]"..
		"label[0.5,1.25;"..S("Station Code").." | "..S("Station Name").."]"..
		get_stn_dropdown(player_to_stn_override[pname] or stdata.stn, pname_unless_admin)..
		"field[7,1.5;1,0.8;track;"..S("Track")..";"..minetest.formspec_escape(stdata.track).."]"..
		"tooltip[track;"..S("Track number, for informational purposes").."]"..
		(advtrains.lines.open_station_editor ~= nil and "button[8.2,1.5;3.3,0.8;editstn;"..S("Station Editor").."]" or "")..
		-- filter/config
		"textarea[0.5,3;6,2;ars;"..S("For trains (ARS rules)")..";"..advtrains.interlocking.ars_to_text(stdata.ars).."]"..
		--"button[7,3;1,0.8;prev_config;<<]"..
		--"button[10.5,3;1,0.8;next_config;>>]"..
		--"dropdown[7,4;4.5,0.8;mode;Normal Stop,Pass Through<NI>,Inactive<NI>;1;true]"..
		--"tooltip[mode;"..S("Select the operation mode:\nNormal Stop: Train stops, waits the specified time and departs\nPass Through: Train does not stop, but records this stop as a timing point\nInactive: The train ignores this stop rail.\nTimetables may override this setting.").."]"..
		--arrival
		"label[0.5,6;"..S("Arrive:").."]"..
		"field[2,5.7;1.5,0.8;wait;"..S("Stop Time")..";"..stdata.wait.."]"..
		"tooltip[wait;"..S("Train will remain stopped with open doors for at least this time before departure is attempted.").."]"..
		"label[4,5.5;"..S("Door Side").."]"..
		"dropdown[4,5.7;2.5,0.8;doors;"..S("left")..","..S("right")..","..S("closed")..";"..door_dropdown[stdata.doors]..";true]"..
		"tooltip[doors;"..S("Select if and on which side the train will open its doors once stopped").."]"..
		"checkbox[7,5.9;reverse;"..S("Reverse train")..";"..(stdata.reverse and "true" or "false").."]"..
		"tooltip[reverse;"..S("Train will depart in the direction from where it arrived").."]"..
		"checkbox[7,6.6;kick;"..S("Kick out passengers")..";"..(stdata.kick and "true" or "false").."]"..
		"checkbox[7,7.3;arskeepen;"..S("Keep ARS enabled")..";"..(stdata.arskeepen and "true" or "false").."]"..
		"tooltip[arskeepen;"..S("Do not disable ARS on approaching. Signals behind the stop rail already set ARS routes when the train arrives, not just before departure. (currently not implemented)").."]"..
		--"textarea[0.5,7;6,1;arr_action;"..S("Arrival Actions")..";<not yet implemented>]"..
		--"tooltip[arr_action;"..S("List of actions to perform on arrival (currently not implemented, later will allow actions such as setting line, RC and displays)").."]"..
		-- departure
		"label[0.5,8.9;"..S("Depart:").."]"..
		"field[2,8.6;1.5,0.8;speed;"..S("Speed")..";"..minetest.formspec_escape(stdata.speed).."]"..
		"tooltip[speed;"..S("Speed that the train sets when departing. Set 'M' for maximum speed.").."]"..
		--"label[4,8.4;"..S("Departure Mode").."<NI>]"..
		--"dropdown[4,8.6;2.5,0.8;depmode;Normal,Interval,Begin Timetable;2;true]"..
		--"tooltip[depmode;"..S("Select the time for departure:\nNormal: depart immediately after the stop time elapsed\nInterval: depart at the next time position set by interval and offset\nBegin Timetable: The train gets the given timetable assigned and departs according to its settings (currently not implemented)").."]"..
		"field[7,8.6;1.8,0.8;interval;"..S("Interval:")..";"..minetest.formspec_escape(stdata.interval or "").."]"..
		"tooltip[interval;"..S("The interval / time distance between departures in seconds. E.g. every two minutes -> set interval = 120").."]"..
		"field[9,8.6;1.8,0.8;ioffset;"..S("Offset:")..";"..minetest.formspec_escape(stdata.ioffset or "0").."]"..
		"tooltip[ioffset;"..S("The offset of departures from time 0:00 in seconds. E.g. interval 120 offset 60 -> departure at every odd minute").."]"..
		"checkbox[7,10.6;keepopen;"..S("Keep doors open")..";"..(stdata.keepopen and "true" or "false").."]"..
		"tooltip[keepopen;"..S("Do not close the doors when departing, if they are open").."]"..
		"checkbox[7,9.9;waitsig;"..S("Wait for signal to clear")..";"..(stdata.waitsig and "true" or "false").."]"..
		"tooltip[waitsig;"..S("Do not depart immediately, instead first enable ARS and wait until the next signal ahead clears (ATC G command) before closing the doors and departing.").."]"..
		--"textarea[0.5,9.9;6,1;dep_action;"..S("Departure Actions")..";<not yet implemented>]"..
		--"tooltip[dep_action;"..S("List of actions to perform on departure (currently not implemented, later will allow actions such as setting line, RC and displays)").."]"..
		-- end
		"button_exit[0.5,11.2;11,0.8;save;"..S("Save").."]"

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

		if fields.save then
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

			stdata.ddelay = nil -- delete legacy field
			
			if fields.speed then
				stdata.speed = to_int(fields.speed) or "M"
			end
			if fields.interval then
				if fields.interval == "" or fields.interval == "0" then
					stdata.interval = nil
				else
					local n = to_int(fields.interval)
					if 0 < n and n <= 3600 then
						stdata.interval = n
					end
				end
			end
			if stdata.interval == nil then
				stdata.ioffset = nil
			elseif set_offset ~= nil then
				stdata.ioffset = set_offset
			elseif fields.ioffset then
				if fields.ioffset == "" or fields.ioffset == "0" then
					stdata.ioffset = nil
				else
					local n = to_int(fields.ioffset)
					if n > 0 then
						stdata.ioffset = n % stdata.interval
					else
						stdata.ioffset = nil
					end
				end
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
