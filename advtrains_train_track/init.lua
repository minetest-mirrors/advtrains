-- advtrains_train_track
-- rewritten to work with advtrains 2.5 track system

local function conns(c1, c2, r1, r2) return {{c=c1, y=r1}, {c=c2, y=r2}} end
local function conns3(c1, c2, c3, r1, r2, r3) return {{c=c1, y=r1}, {c=c2, y=r2}, {c=c3, y=r3}} end


local common_def = {
	drawtype = "mesh",
	paramtype = "light",
	paramtype2 = "facedir",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/2-1/16, -1/2, -1/2, 1/2+1/16, -1/2+2/16, 1/2},
	},

	mesh_suffix = ".b3d",
	tiles = { "advtrains_dtrack_shared.png" },
	
	groups = {
		advtrains_track=1,
		advtrains_track_default=1,
		dig_immediate=2,
		--not_in_creative_inventory=1,
	},
		
	can_dig = advtrains.track_can_dig_callback,
	after_dig_node = advtrains.track_update_callback,
	after_place_node = advtrains.track_update_callback,
	
	drop = "advtrains:dtrack_placer"
}

-- Normal tracks, straight and curved
advtrains.register_node_4rot("advtrains:dtrack_st",
	advtrains.merge_tables(common_def, {
		description=attrans("Track Straight"),
		mesh_prefix="advtrains_dtrack_st",
		at_conns = conns(0,8),
		advtrains = {
			trackworker_next_var = "advtrains:dtrack_cr",
			track_place_group = "advtrains:dtrack",
			track_place_single = true,
		},
	})
)

advtrains.register_node_4rot("advtrains:dtrack_cr",
	advtrains.merge_tables(common_def, {
		description=attrans("Track Curve"),
		mesh_prefix="advtrains_dtrack_cr",
		at_conns = conns(0,7),
		advtrains = {
			trackworker_next_var = "advtrains:dtrack_swlst",
			track_place_group = "advtrains:dtrack",
		},
	})
)

-- simple turnouts left and right

local stm_left = {
	st = "advtrains:dtrack_swlst",
	cr = "advtrains:dtrack_swlcr",
}

advtrains.register_node_4rot("advtrains:dtrack_swlst",
	advtrains.merge_tables(common_def, {
		description=attrans("Track Turnout Left Straight"),
		mesh_prefix="advtrains_dtrack_swlst",
		at_conns = conns3(0,8,7),
		at_conn_map = {2,1,1},
		on_rightclick = advtrains.state_node_on_rightclick_callback,
		advtrains = {
			node_state = "st",
			node_next_state = "cr",
			node_state_map = stm_left,
			trackworker_next_var = "advtrains:dtrack_swrst"
		},
	})
)

advtrains.register_node_4rot("advtrains:dtrack_swlcr",
	advtrains.merge_tables(common_def, {
		description=attrans("Track Turnout Left Curve"),
		mesh_prefix="advtrains_dtrack_swlcr",
		at_conns = conns3(0,8,7), -- note: conns must stay identical
		at_conn_map = {3,1,1}, -- now points to curve branch
		on_rightclick = advtrains.state_node_on_rightclick_callback,
		advtrains = {
			node_state = "cr",
			node_next_state = "st",
			node_state_map = stm_left,
			trackworker_next_var = "advtrains:dtrack_swrcr"
		},
	})
)

local stm_right = {
	st = "advtrains:dtrack_swrst",
	cr = "advtrains:dtrack_swrcr",
}

advtrains.register_node_4rot("advtrains:dtrack_swrst",
	advtrains.merge_tables(common_def, {
		description=attrans("Track Turnout Right Straight"),
		mesh_prefix="advtrains_dtrack_swrst",
		at_conns = conns3(0,8,9),
		at_conn_map = {2,1,1},
		on_rightclick = advtrains.state_node_on_rightclick_callback,
		advtrains = {
			node_state = "st",
			node_next_state = "cr",
			node_state_map = stm_right,
			trackworker_next_var = "advtrains:dtrack_st"
		},
	})
)

advtrains.register_node_4rot("advtrains:dtrack_swrcr",
	advtrains.merge_tables(common_def, {
		description=attrans("Track Turnout Right Curve"),
		mesh_prefix="advtrains_dtrack_swrcr",
		at_conns = conns3(0,8,9), -- note: conns must stay identical
		at_conn_map = {3,1,1}, -- now points to curve branch
		on_rightclick = advtrains.state_node_on_rightclick_callback,
		advtrains = {
			node_state = "cr",
			node_next_state = "st",
			node_state_map = stm_right,
			trackworker_next_var = "advtrains:dtrack_st"
		},
	})
)

-- register placer item
minetest.register_craftitem(":advtrains:dtrack_placer", {
	description = attrans("Track"),
	inventory_image = "advtrains_dtrack_placer.png",
	wield_image = "advtrains_dtrack_placer.png",
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
						advtrains.trackplacer.place_track(pos, "advtrains:dtrack", name, yaw)
						if not advtrains.is_creative(name) then
							itemstack:take_item()
						end
					end
				end
			end
			return itemstack, true
	end,
})


--TODO restore mesecons!