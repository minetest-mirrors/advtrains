-- stoprail.lua
-- adds "stop rail". Recognized by lzb. (part of behavior is implemented there)

-- Get current translator
local S = advtrains.lines.translate

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
	
	meta:set_string("infotext", "Stn. "..stdata.stn.." T. "..stdata.track)
end

local door_dropdown = {L=1, R=2, C=3}
--local door_dropdown_rev = {Right="R", Left="L", Closed="C"} -- Code review : why are the value in an order different than the one in the dropdown box ?
local door_dropdown_code = {"L", "R", "C"} -- switch to numerical index of selection : for conversion of the numerical index in the opening side selection dropdown box to the internal codification

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
					stn="", track="", doors="R", wait=10, ars={default=true}, ddelay=1,speed="M"
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
	
	local form = "size[8,7]"
	form = form.."style[stn,ars;font=mono]"
	form = form.."field[0.8,0.8;2,1;stn;"..S("Station Code")..";"..minetest.formspec_escape(stdata.stn).."]"
	form = form.."field[2.8,0.8;5,1;stnname;"..S("Station Name")..";"..minetest.formspec_escape(stnname).."]"
	form = form.."field[0.80,2.0;1.75,1;ddelay;"..S("Door Delay")..";"..minetest.formspec_escape(stdata.ddelay).."]"
	form = form.."field[2.55,2.0;1.75,1;speed;"..S("Dep. Speed")..";"..minetest.formspec_escape(stdata.speed).."]"
	form = form.."field[4.30,2.0;1.75,1;track;"..S("Track")..";"..minetest.formspec_escape(stdata.track).."]"
	form = form.."field[6.05,2.0;1.75,1;wait;"..S("Stop Time")..";"..stdata.wait.."]"
	form = form.."label[0.5,2.6;"..S("Door Side").."]"
	form = form.."dropdown[0.51,3.0;2;doors;"..S("Left")..","..S("Right")..","..S("Closed")..";"..door_dropdown[stdata.doors]..";true]" -- switch to numerical index of the selection
	form = form.."checkbox[3.00,2.4;reverse;"..S("Reverse train")..";"..(stdata.reverse and "true" or "false").."]"
	form = form.."checkbox[3.00,2.8;kick;"..S("Kick out passengers")..";"..(stdata.kick and "true" or "false").."]"
	form = form.."checkbox[3.00,3.2;waitsig;"..S("Wait for signal to clear")..";"..(stdata.waitsig and "true" or "false").."]"
	form = form.."textarea[0.8,4.2;7,2;ars;"..S("Trains stopping here (ARS rules)")..";"..advtrains.interlocking.ars_to_text(stdata.ars).."]"
	form = form.."button[0.5,6;7,1;save;"..S("Save").."]"
	
	minetest.show_formspec(pname, "at_lines_stop_"..pe, form)
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
		if fields.save then
			if fields.stn and stdata.stn ~= fields.stn and fields.stn ~= "" then
				local stn = advtrains.lines.stations[fields.stn]
				if stn then
					if (stn.owner == pname or minetest.check_player_privs(pname, "train_admin")) then
						stdata.stn = fields.stn
					else
						minetest.chat_send_player(pname, S("Station code \"@1\" already exists and is owned by @2.", fields.stn, stn.owner))
						show_stoprailform(pos,player)
						return
					end
				else
					advtrains.lines.stations[fields.stn] = {name = fields.stnname, owner = pname}
					stdata.stn = fields.stn
				end
			end
			local stn = advtrains.lines.stations[stdata.stn]
			if stn and fields.stnname and fields.stnname~="" and fields.stnname ~= stn.name then
				if (stn.owner == pname or minetest.check_player_privs(pname, "train_admin")) then
					stn.name = fields.stnname
				else
					minetest.chat_send_player(pname, S("This station is owned by @1. You are not allowed to edit its name.", stn.owner))
				end
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

			if fields.ddelay then
				stdata.ddelay = to_int(fields.ddelay) or 1
			end
			if fields.speed then
				stdata.speed = to_int(fields.speed) or "M"
			end

			for k,v in pairs(tmp_checkboxes[pe]) do --handle checkboxes
				stdata[k] = v or nil
			end
			tmp_checkboxes[pe] = nil
			--TODO: signal
			updatemeta(pos)
			show_stoprailform(pos, player)
		end
	end			
	
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
			on_rightclick = function(pos, node, player)
				show_stoprailform(pos, player)
			end,
			advtrains = {
				on_train_approach = function(pos,train_id, train, index, has_entered)
					if has_entered then return end -- do not stop again!
					if train.path_cn[index] == 1 then
						local pe = advtrains.encode_pos(pos)
						local stdata = advtrains.lines.stops[pe]
						if stdata and stdata.stn then
						
							--TODO REMOVE AFTER SOME TIME (only migration)
							if not stdata.ars then
								stdata.ars = {default=true}
							end
							if stdata.ars and (stdata.ars.default or advtrains.interlocking.ars_check_rule_match(stdata.ars, train) ) then
								advtrains.lzb_add_checkpoint(train, index, 2, nil)
								local stn = advtrains.lines.stations[stdata.stn]
								local stnname = stn and stn.name or S("Unknown Station")
								train.text_inside = S("Next Stop:\n")..stnname
								advtrains.interlocking.ars_set_disable(train, true)
							end
						end
					end
				end,
				on_train_enter = function(pos, train_id, train, index)
					if train.path_cn[index] == 1 then
						local pe = advtrains.encode_pos(pos)
						local stdata = advtrains.lines.stops[pe]
						if not stdata then
							return
						end
						
						if stdata.ars and (stdata.ars.default or advtrains.interlocking.ars_check_rule_match(stdata.ars, train) ) then
							local stn = advtrains.lines.stations[stdata.stn]
							local stnname = stn and stn.name or S("Unknown Station")
							
							-- Send ATC command and set text
							advtrains.atc.train_set_command(train, "B0 W O"..stdata.doors..(stdata.kick and "K" or "")
																	.." D"..stdata.wait.." "..(stdata.reverse and "R" or "")
																	.." A1 "..(stdata.waitsig and "G" or "")
																	.." OC D"..(stdata.ddelay or 1) .. " S" ..(stdata.speed or "M"), true)
							train.text_inside = stnname
							if tonumber(stdata.wait) then
								minetest.after(tonumber(stdata.wait), function() train.text_inside = "" end)
							end
						end
					end
				end
			},
		}
end

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
end
