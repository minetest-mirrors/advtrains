local F = advtrains.formspec
local D = advtrains.distant
local I = advtrains.interlocking

function advtrains.interlocking.show_distant_signal_form(pos, pname)
	local form = {"size[7,7]"}
	form[#form+1] = advtrains.interlocking.make_signal_formspec_tabheader(pname, pos, 7, 3)
	local main, set_by = D.get_main(pos)
	if main then
		local pts_main = minetest.pos_to_string(main)
		form[#form+1] = F.S_label(0.5, 0.5, "This signal is a distant signal of @1.", pts_main)
		if set_by == "manual" then
			form[#form+1] = F.S_label(0.5, 1, "The assignment is made manually.")
		elseif set_by == "routesetting" then
			form[#form+1] = F.S_label(0.5, 1, "The assignment is made by the routesetting system.")
		end
	else
		form[#form+1] = F.S_label(0.5, 0.5, "This signal is not assigned to a main signal.")
		form[#form+1] = F.S_label(0.5, 1, "The distant aspect of the signal is not used.")
	end
	if set_by ~= nil then
		form[#form+1] = F.S_button_exit(0.5, 1.5, 3, 1, "unassign_dst", "Unassign")
		form[#form+1] = F.S_button_exit(3.5, 1.5, 3, 1, "assign_dst", "Reassign")
	else
		form[#form+1] = F.S_button_exit(0.5, 1.5, 6, 1, "assign_dst", "Assign")
	end

	local dsts = D.get_dst(pos)
	local dstlist = {}
	for pos, _ in pairs(dsts) do
		dstlist[#dstlist+1] = minetest.pos_to_string(advtrains.decode_pos(pos))
	end
	form[#form+1] = F.S_label(0.5, 2.5, "This signal has the following distant signals:")
	form[#form+1] = F.textlist(0.5, 3, 4.5, 3.5, "dstlist", dstlist)
	form[#form+1] = F.image_button_exit(5.5, 3.5, 1, 1, "cdb_add.png", "dst_add", "")
	form[#form+1] = F.image_button_exit(5.5, 5, 1, 1, "cdb_clear.png", "dst_del", "")
	minetest.show_formspec(pname, "advtrains:distant_" .. minetest.pos_to_string(pos), table.concat(form))
end

local signal_pos = {}
local function init_signal_assignment(pname, pos)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, attrans("This operation is not allowed without the @1 privilege.", "interlocking"))
		return
	end
	signal_pos[pname] = pos
	minetest.chat_send_player(pname, attrans("Please punch the signal to use as the main signal."))
end

local distant_pos = {}
local function init_distant_assignment(pname, pos)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.send_chat_player(pname, attrans("This operation is now allowed without the @1 privilege.", "interlocking"))
		return
	end
	distant_pos[pname] = pos
	minetest.chat_send_player(pname, attrans("Please punch the signal to use as the distant signal."))
end

minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local spos = signal_pos[pname]
	local distant = false
	if not spos then
		spos = distant_pos[pname]
		if not spos then
			return
		end
		distant = true
	end
	signal_pos[pname] = nil
	distant_pos[pname] = nil
	local is_signal = minetest.get_item_group(node.name, "advtrains_signal") >= 2
	if not is_signal then
		minetest.chat_send_player(pname, attrans("Incompatible signal."))
		return
	end
	minetest.chat_send_player(pname, attrans("Successfully assigned signal."))
	if distant then
		D.assign(spos, pos, "manual")
	else
		D.assign(pos, spos, "manual")
	end
end)

local dstsel = {}
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local pos = minetest.string_to_pos(string.match(formname, "^advtrains:distant_(.+)$") or "")
	if not pos then
		return
	end
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	if advtrains.interlocking.handle_signal_formspec_tabheader_fields(pname, fields) then
		return true
	end
	if fields.unassign_dst then
		D.unassign_dst(pos)
	elseif fields.assign_dst then
		init_signal_assignment(pname, pos)
	elseif fields.dst_add then
		init_distant_assignment(pname, pos)
	elseif fields.dstlist then
		dstsel[pname] = minetest.explode_textlist_event(fields.dstlist).index
	elseif fields.dst_del then
		local selid = dstsel[pname]
		if selid then
			local dsts = D.get_dst(pos)
			local pos
			for p, _ in pairs(dsts) do
				selid = selid-1
				if selid <= 0 then
					pos = p
					break
				end
			end
			if pos then
				D.unassign_dst(advtrains.decode_pos(pos))
			end
		end
	end
end)
