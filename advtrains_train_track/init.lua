-- advtrains_train_track
-- rewritten to work with advtrains 2.5 track system, but mimics the "old" template-based track registration
-- Also, since 2.5, all tracks are moved here, even the ATC, LuaATC and Interlocking special tracks

local function conns(c1, c2, r1, r2) return {{c=c1, y=r1}, {c=c2, y=r2}} end
local function conns3(c1, c2, c3, r1, r2, r3) return {{c=c1, y=r1}, {c=c2, y=r2}, {c=c3, y=r3}} end


local function register(reg)
	for sgi, sgrp in ipairs(reg.sgroups) do
		-- prepare the state map if we need it later
		local state_map = {}
		if sgrp.turnout then
			for vn,var in pairs(sgrp.variants) do
				local name = reg.base .. "_" .. vn
				state_map[var.state] = name
			end
		end
		-- iterate through each of the variants
		for vn,var in pairs(sgrp.variants) do
			local name = reg.base .. "_" .. vn
			local ndef = {
				description = reg.description .. " " .. vn,
				drawtype = "mesh",
				paramtype = "light",
				paramtype2 = "facedir",
				walkable = false,
				selection_box = {
					type = "fixed",
					fixed = {-1/2-1/16, -1/2, -1/2, 1/2+1/16, -1/2+2/16, 1/2},
				},

				mesh_prefix=reg.mprefix.."_"..vn,
				mesh_suffix = ".b3d",
				tiles = { "advtrains_dtrack_shared.png" },
				
				groups = {
					advtrains_track=1,
					advtrains_track_default=1,
					dig_immediate=2,
					--not_in_creative_inventory=1,
				},
				
				at_conns = sgrp.conns,
				at_conn_map = var.conn_map,
					
				can_dig = advtrains.track_can_dig_callback,
				after_dig_node = advtrains.track_update_callback,
				after_place_node = advtrains.track_update_callback,
				
				advtrains = {
					trackworker_next_var = reg.base .. "_" .. var.next_var
				}
			}
			-- drop field
			if reg.register_placer then
				ndef.drop = reg.base.."_placer"
			else
				ndef.drop = reg.drop
			end
			-- if variant is suitable for autoplacing (trackplacer)
			if var.track_place then
				ndef.advtrains.track_place_group = reg.base
				ndef.advtrains.track_place_single = var.track_place_single
			end
			-- turnout handling
			-- if the containing group was a turnout group, the containing state_map will be used
			if sgrp.turnout then
				ndef.on_rightclick = advtrains.state_node_on_rightclick_callback
				ndef.advtrains.node_state = var.state
				ndef.advtrains.node_next_state = var.next_state
				ndef.advtrains.node_state_map = state_map
			end
			-- use advtrains-internal function to register the 4 rotations of the node, to make our life easier
			--atdebug("Registering: ",name, ndef) -- for debugging it can be useful to output what is being registered
			advtrains.register_node_4rot(name, ndef)
		end
	end
	if reg.register_placer then
		local tpgrp = reg.base
		minetest.register_craftitem(":advtrains:dtrack_placer", {
			description = reg.description,
			inventory_image = reg.mprefix.."_placer.png",
			wield_image = reg.mprefix.."_placer.png",
			groups={advtrains_trackplacer=1, digtron_on_place=1},
			liquids_pointable = false,
			on_place = function(itemstack, placer, pointed_thing)
				local name = placer:get_player_name()
				if not name then
				   return itemstack, false
				end
				if pointed_thing.type=="node" then
					local pos=pointed_thing.above
					local upos=vector.subtract(pointed_thing.above, {x=0, y=1, z=0})
					if not advtrains.check_track_protection(pos, name) then
						return itemstack, false
					end
					if minetest.registered_nodes[minetest.get_node(pos).name] and minetest.registered_nodes[minetest.get_node(pos).name].buildable_to then
						local s = minetest.registered_nodes[minetest.get_node(upos).name] and minetest.registered_nodes[minetest.get_node(upos).name].walkable
						if s then
	--						minetest.chat_send_all(nnprefix)
							local yaw = placer:get_look_horizontal()
							advtrains.trackplacer.place_track(pos, tpgrp, name, yaw)
							if not advtrains.is_creative(name) then
								itemstack:take_item()
							end
						end
					end
				end
				return itemstack, true
			end,
		})
	end
end



-- normal dtrack
register({
	base = "advtrains:dtrack",
	mprefix = "advtrains_dtrack",
	description = attrans("Track"),
	
	sgroups = { -- integer-indexed table, we don't need a key here
		-- inside are "variant" tables
		{
			variants = {
				st = {
					next_var = "cr",
					track_place = true,
					track_place_single = true,
				},
			},
			conns = conns(0,8),
		},
		{
			variants = {
				cr = {
					next_var = "swlst",
					track_place = true,
				},
			},
			conns = conns(0,7),
		},
		{
			turnout = true,
			variants = {
				swlst = {
					next_var = "swrst",
					conn_map = {2,1,1},
					state = "st",
					next_state = "cr",
				},
				swlcr = {
					next_var = "swrcr",
					conn_map = {3,1,1},
					state = "cr",
					next_state = "st",
				},
			},
			conns = conns3(0,8,7),
		},
		{
			turnout = true,
			variants = {
				swrst = {
					next_var = "st",
					conn_map = {2,1,1},
					state = "st",
					next_state = "cr",
				},
				swrcr = {
					next_var = "st",
					conn_map = {3,1,1},
					state = "cr",
					next_state = "st",
				},
			},
			conns = conns3(0,8,9),
		},
	},
	register_placer = true,
})

----------------------