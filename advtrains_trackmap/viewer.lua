-- viewer.lua
-- standalone chatcommand/tool trackmap viewer window

local tm = advtrains.trackmap

local function node_left_click(pos, pname)
	local node_ok, conns, rail_y=advtrains.get_rail_info_at(pos)
	if not node_ok then
		minetest.chat_send_player(pname, "Node is not a track!")
		return
	end
	
	local function node_callback()
		return nil
	end

	local gridtbl = tm.generate_grid_map(pos, node_callback)
	local fslabel = tm.render_grid(gridtbl.grid, gridtbl.min_pos, 100, 100)
	
	minetest.show_formspec(pname, "advtrains_trackmap:test", "size[20,20]"..fslabel)
end


minetest.register_craftitem("advtrains_trackmap:tool",{
	description = "Trackmap Tool\nPunch: Show map",
	groups = {cracky=1}, -- key=name, value=rating; rating=1..3.
	inventory_image = "at_il_tool.png",
	wield_image = "at_il_tool.png",
	stack_max = 1,
	on_use = function(itemstack, player, pointed_thing)
		local pname = player:get_player_name()
		if not pname then
			return
		end
		if not minetest.check_player_privs(pname, {interlocking=true}) then
			minetest.chat_send_player(pname, "Insufficient privileges to use this!")
			return
		end
		if pointed_thing.type=="node" then
			local pos=pointed_thing.under
			node_left_click(pos, pname)
		end
	end
})