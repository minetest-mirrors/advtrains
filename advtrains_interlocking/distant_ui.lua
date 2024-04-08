local F = advtrains.formspec
local D = advtrains.distant
local I = advtrains.interlocking

function I.make_short_dst_formspec_component(pos, x, y, w)
	local main, set_by = D.get_main(pos)
	if main then
		local pts_main = minetest.pos_to_string(main)
		local desc = attrans("The assignment is made with an unknown method.")
		if set_by == "manual" then
			desc = attrans("The assignment is made manually.")
		elseif set_by == "routesetting" then
			desc = attrans("The assignment is made by the routesetting system.")
		end
		return table.concat {
			F.S_label(x, y, "This signal is a distant signal of @1.", pts_main),
			F.label(x, y+0.5, desc),
			F.S_button_exit(x, y+1, w/2-0.125, "dst_assign", "Reassign"),
			F.S_button_exit(x+w/2+0.125, y+1, w/2-0.125, "dst_unassign", "Unassign"),
		}
	else
		return table.concat {
			F.S_label(x, y, "This signal is not assigned to a main signal."),
			F.S_label(x, y+0.5, "The distant aspect of the signal is not used."),
			F.S_button_exit(x, y+1, w, "dst_assign", "Assign")
		}
	end
end

function I.make_dst_list_formspec_component(pos, x, y, w, h)
	local ymid = y+0.25+h/2
	local dstlist = {}
	for pos, _ in pairs(D.get_dst(pos)) do
		table.insert(dstlist, minetest.pos_to_string(advtrains.decode_pos(pos)))
	end
	return table.concat {
		F.S_label(x, y, "Distant signals:"),
		F.textlist(x, y+0.5, w-1, h-0.5, "dstlist", dstlist),
		F.image_button_exit(x+w-0.75, ymid-0.875, 0.75, 0.75, "cdb_add.png", "dst_add", ""),
		F.image_button_exit(x+w-0.75, ymid+0.125, 0.75, 0.75, "cdb_clear.png", "dst_del", ""),
	}
end

function I.make_dst_formspec_component(pos, x, y, w, h)
	return I.make_short_dst_formspec_component(pos, x, y, w, h)
		.. I.make_dst_list_formspec_component(pos, x, y+2, w, h-2)
end

function I.show_distant_signal_form(pos, pname)
	return I.show_ip_form(pos, pname)
end

local signal_pos = {}
local function init_signal_assignment(pname, pos)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, attrans("This operation is not allowed without the @1 privilege.", "interlocking"))
		return
	end
	if not D.appropriate_signal(pos) then
		minetest.chat_send_player(pname, attrans("Incompatible signal."))
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
	if not D.appropriate_signal(pos) then
		minetest.chat_send_player(pname, attrans("Incompatible signal."))
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
	if not (is_signal and D.appropriate_signal(pos)) then
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

function advtrains.interlocking.handle_dst_formspec_fields(pname, pos, fields)
	if not (pos and minetest.check_player_privs(pname, "interlocking")) then
		return
	end
	if fields.dst_unassign then
		D.unassign_dst(pos)
	elseif fields.dst_assign then
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
end
