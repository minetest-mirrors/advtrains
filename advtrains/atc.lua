--atc.lua
--registers and controls the ATC system

local atc={}

local eval_conditional

-- ATC persistence table. advtrains.atc is created by init.lua when it loads the save file.
atc.controllers = {}
function atc.load_data(data)
	local temp = data and data.controllers or {}
	--transcode atc controller data to node hashes: table access times for numbers are far less than for strings
	for pts, data in pairs(temp) do
		if type(pts)=="number" then
			pts=minetest.pos_to_string(minetest.get_position_from_hash(pts))
		end
		atc.controllers[pts] = data
	end
end
function atc.save_data()
	return {controllers = atc.controllers}
end
--contents: {command="...", arrowconn=0-15 where arrow points}

--general
function atc.train_set_command(train, command, arrow)
	atc.train_reset_command(train, true)
	train.atc_delay = 0
	train.atc_arrow = arrow
	train.atc_command = command
end

function atc.send_command(pos, par_tid)
	local pts=minetest.pos_to_string(pos)
	if atc.controllers[pts] then
		--atprint("Called send_command at "..pts)
		local train_id = par_tid or advtrains.get_train_at_pos(pos)
		if train_id then
			if advtrains.trains[train_id] then
				--atprint("send_command inside if: "..sid(train_id))
				if atc.controllers[pts].arrowconn then
					atlog("ATC controller at",pts,": This controller had an arrowconn of", atc.controllers[pts].arrowconn, "set. Since this field is now deprecated, it was removed.")
					atc.controllers[pts].arrowconn = nil
				end
				
				local train = advtrains.trains[train_id]
				local index = advtrains.path_lookup(train, pos)
				
				local iconnid = 1
				if index then
					iconnid = train.path_cn[index]
				else
					atwarn("ATC rail at", pos, ": Rail not on train's path! Can't determine arrow direction. Assuming +!")
				end
				
				local command = atc.controllers[pts].command
				
				atc.train_set_command(train, command, iconnid==1)
				atprint("Sending ATC Command to", train_id, ":", command, "iconnid=",iconnid)
				return true
				
			else
				atwarn("ATC rail at", pos, ": Sending command failed: The train",train_id,"does not exist. This seems to be a bug.")
			end
		else
			atwarn("ATC rail at", pos, ": Sending command failed: There's no train at this position. This seems to be a bug.")
			-- huch
			--local train = advtrains.trains[train_id_temp_debug]
			--atlog("Train speed is",train.velocity,", have moved",train.dist_moved_this_step,", lever",train.lever)
			--advtrains.path_print(train, atlog)
			-- TODO track again when ATC bugs occur...
			
		end
	else
		atwarn("ATC rail at", pos, ": Sending command failed: Entry for controller not found.")
		atwarn("ATC rail at", pos, ": Please visit controller and click 'Save'")
	end
	return false
end

-- Resets any ATC commands the train is currently executing, including the target speed (tarvelocity) it is instructed to hold
-- if keep_tarvel is set, does not clear the tarvelocity
function atc.train_reset_command(train, keep_tarvel)
	train.atc_command=nil
	train.atc_delay=nil
	train.atc_brake_target=nil
	train.atc_wait_finish=nil
	train.atc_arrow=nil
	if not keep_tarvel then
		train.tarvelocity=nil
	end
end

--nodes
local idxtrans={static=1, mesecon=2, digiline=3}
local apn_func=function(pos)
	-- FIX for long-persisting ndb bug: there's no node in parameter 2 of this function!
	local meta=minetest.get_meta(pos)
	if meta then
		meta:set_string("infotext", attrans("ATC controller, unconfigured."))
		meta:set_string("formspec", atc.get_atc_controller_formspec(pos, meta))
	end
end

advtrains.atc_function = function(def, preset, suffix, rotation)
		return {
			after_place_node=apn_func,
			after_dig_node=function(pos)
				advtrains.invalidate_all_paths(pos)
				advtrains.ndb.clear(pos)
				local pts=minetest.pos_to_string(pos)
				atc.controllers[pts]=nil
			end,
			on_receive_fields = function(pos, formname, fields, player)
				if advtrains.is_protected(pos, player:get_player_name()) then
					minetest.record_protection_violation(pos, player:get_player_name())
					return
				end
				local meta=minetest.get_meta(pos)
				if meta then
					if not fields.save then 
						--[[--maybe only the dropdown changed
						if fields.mode then
							meta:set_string("mode", idxtrans[fields.mode])
							if fields.mode=="digiline" then
								meta:set_string("infotext", attrans("ATC controller, mode @1\nChannel: @2", fields.mode, meta:get_string("command")) )
							else
								meta:set_string("infotext", attrans("ATC controller, mode @1\nCommand: @2", fields.mode, meta:get_string("command")) )
							end
							meta:set_string("formspec", atc.get_atc_controller_formspec(pos, meta))
						end]]--
						return
					end
					--meta:set_string("mode", idxtrans[fields.mode])
					meta:set_string("command", fields.command)
					--meta:set_string("command_on", fields.command_on)
					meta:set_string("channel", fields.channel)
					--if fields.mode=="digiline" then
					--	meta:set_string("infotext", attrans("ATC controller, mode @1\nChannel: @2", fields.mode, meta:get_string("command")) )
					--else
					meta:set_string("infotext", attrans("ATC controller, mode @1\nCommand: @2", "-", meta:get_string("command")) )
					--end
					meta:set_string("formspec", atc.get_atc_controller_formspec(pos, meta))
					
					local pts=minetest.pos_to_string(pos)
					local _, conns=advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
					atc.controllers[pts]={command=fields.command}
					if #advtrains.occ.get_trains_at(pos) > 0 then
						atc.send_command(pos)
					end
				end
			end,
			advtrains = {
				on_train_enter = function(pos, train_id)
					atc.send_command(pos, train_id)
				end,
			},
		}
end

function atc.get_atc_controller_formspec(pos, meta)
	local mode=tonumber(meta:get_string("mode")) or 1
	local command=meta:get_string("command")
	local command_on=meta:get_string("command_on")
	local channel=meta:get_string("channel")
	local formspec="size[8,6]"
	--	"dropdown[0,0;3;mode;static,mesecon,digiline;"..mode.."]"
	if mode<3 then
		formspec=formspec
			.."style[command;font=mono]"
			.."field[0.8,1.5;7,1;command;"..attrans("Command")..";"..minetest.formspec_escape(command).."]"
		if tonumber(mode)==2 then
			formspec=formspec
				.."style[command_on;font=mono]"
				.."field[0.8,3;7,1;command_on;"..attrans("Command (on)")..";"..minetest.formspec_escape(command_on).."]"
		end
	else
		formspec=formspec.."field[0.8,1.5;7,1;channel;"..attrans("Digiline channel")..";"..minetest.formspec_escape(channel).."]"
	end
	return formspec.."button_exit[0.5,4.5;7,1;save;"..attrans("Save").."]"
end

function atc.execute_atc_command(id, train)
	local w, e = advtrains.atcjit.execute(id, train)
	if w then
		for i = 1, #w, 1 do
			atwarn(sid(id),w[i])
		end
	end
	if e then
		atwarn(sid(id),e)
		atc.train_reset_command(train, true)
	end
end

minetest.register_chatcommand("at_get_lua",{
	params = "<command>",
	description = "Compile the given ATC command into Lua code and show the given code",
	privs = {train_admin = true},
	func = function(name, params)
		local f, s = advtrains.atcjit.compile(params)
		if not f then	
			return false, s or ("Unknown compilation error")
		else
			return true, s
		end
	end,
})

--move table to desired place
advtrains.atc=atc
