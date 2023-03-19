-- tool.lua
-- Interlocking tool

local ilrs = advtrains.interlocking.route

local function node_right_click(pos, pname)
	if advtrains.is_passive(pos) then
		local form = "size[7,5]label[0.5,0.5;Route lock inspector]"
		local pts = minetest.pos_to_string(pos)
		
		local rtl = ilrs.has_route_lock(pts)
		
		if rtl then
			form = form.."label[0.5,1;Route locks currently put:\n"..rtl.."]"
			form = form.."button_exit[0.5,3.5;  5,1;clear;Clear]"
		else
			form = form.."label[0.5,1;No route locks set]"
			form = form.."button_exit[0.5,3.5;  5,1;emplace;Emplace manual lock]"
		end
		
		minetest.show_formspec(pname, "at_il_rtool_"..pts, form)
		return
	end

	-- If not a turnout, check the track section and show a form
	local node_ok, conns, rail_y=advtrains.get_rail_info_at(pos)
	if not node_ok then
		minetest.chat_send_player(pname, "Node is not a track!")
		return
	end
	if advtrains.interlocking.db.get_tcb(pos) then
		advtrains.interlocking.show_tcb_form(pos, pname)
		return
	end

	local ts_id = advtrains.interlocking.db.check_and_repair_ts_at_pos(pos)
	if ts_id then
		advtrains.interlocking.show_ts_form(ts_id, pname)
	else
		minetest.chat_send_player(pname, "No track section at this location!")
	end
end

local function node_left_click(pos, pname)
	local node_ok, conns, rail_y=advtrains.get_rail_info_at(pos)
	if not node_ok then
		minetest.chat_send_player(pname, "Node is not a track!")
		return
	end

	if advtrains.interlocking.db.get_tcb(pos) then
		advtrains.interlocking.show_tcb_marker(pos)
		return
	end

	local ts_id = advtrains.interlocking.db.check_and_repair_ts_at_pos(pos)
	if ts_id then
		advtrains.interlocking.highlight_track_section(pos)
	else
		minetest.chat_send_player(pname, "No track section at this location!")
	end
end


minetest.register_craftitem("advtrains_interlocking:tool",{
	description = "Interlocking tool\nPunch: Highlight track section\nPlace: check route locks/show track section info",
	groups = {cracky=1}, -- key=name, value=rating; rating=1..3.
	inventory_image = "at_il_tool.png",
	wield_image = "at_il_tool.png",
	stack_max = 1,
	on_place = function(itemstack, player, pointed_thing)
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
			node_right_click(pos, pname)
		end
	end,
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

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local pos
	local pts = string.match(formname, "^at_il_rtool_(.+)$")
	if pts then
		pos = minetest.string_to_pos(pts)
	end
	if pos then
		if advtrains.is_passive(pos) then
			if fields.clear then
				ilrs.remove_route_locks(pts)
			end
			if fields.emplace then
				ilrs.add_manual_route_lock(pts, "Manual lock ("..pname..")")
			end
		end
	end
end)
