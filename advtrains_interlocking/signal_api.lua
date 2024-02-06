-- Signal API implementation

local F = advtrains.formspec

local signal = {}

signal.MASP_HALT = {
	name = "halt"
	halt = true,
}

signal.ASPI_HALT = {
	main = 0,
	shunt = false,
}

signal.ASPI_FREE = {
	main = -1,
	shunt = false,
	proceed_as_main = true,
}

--[[
Implementation plan orwell 2024-01-28:
Most parts of ywang's implementation are fine, especially I like the formspecs. But I would like to change a few aspects (no pun intended) of this.
- Signal gets distant assigned via field in signal aspect table (instead of explicitly)
- Signal speed/shunt are no longer free-text but rather they need to be predefined in the node definition
To do this: Differentiation between:
== Main Aspect ==
This is what a signal is assigned by either the route system or the user.
It is a string key which has an appropriate entry in the node definition (where it has a description assigned)
The signal mod defines a function to set a signal to the most appropriate aspect. This function gets
a) the main aspect table (straight from node def)
b) the distant signal's aspect group name & aspect table

== Aspect ==
One concrete combination of lights/shapes that a signal signal shows. Handling these is at the discretion of
the signal mod defining the signal, and they are typically combinations of main aspect and distant aspect
Example:
- A Ks signal has the aspect_group="proceed_12" set for a route
- The signal at the end of the route shows aspect_group="proceed_8", advtrains also passes on that this means {main=8, shunt=false}
- The ndef.advtrains.apply_aspect(pos, asp_group, dst_aspgrp, dst_aspinfo) determines that the signal should now show
		blinking green with main indicator 12 and dst indicator 8, and sets the nodes accordingly.
		This function can now return the Aspect Info table, which will be cached by advtrains until the aspect changes again
		and will be used when a train approaches the signal. If nil is returned, then the aspect will be queried next time
		by calling ndef.advtrains.get_aspect_info(pos)

Note that once apply_aspect returns, there is no need for advtrains anymore to query the aspect info.
When the signal, for any reason, wants to change its aspect by itself *without* going through the signal API then
it should update the aspect info cache by calling advtrains.interlocking.signal.update_aspect_info(pos)

Note that the apply_aspect function MUST accept the following main aspect, even if it is not defined in the main_aspects table:
{ name = "halt", halt = true }
It should cause the signal to show its most restrictive aspect. Typically it is a halt aspect, but e.g. for distant-only
signals this would be "expect stop".

== Aspect Info ==
The actual signal aspect in the already-known format. This is what the trains use to determine halt/proceed and speed. In this, the dst field has to be resolved.
asp = {
	main = 0 (halt) / -1 (max speed) / false (no info) / <number> (speed limit)
	shunt = true (shunt free) / false (shunt not free)
	proceed_as_main = true (shunt move can proceed and become train move when main!=0) / false (no)
	dst = (like main, informative character, not actually used)
}

Node definition of signals:
- The signal needs some logic to figure out, for each combination of its own aspect group and the distant signal's aspect, what aspect info it can/will show.
ndef.advtrains = {
	main_aspects = {
		{ name = "proceed" description = "Proceed at full speed", <more data at discretion of signal>}
		{ name = "proceed2" description = "Proceed at full speed", <more data at discretion of signal>}
	} -- The numerical order determines the layout of the list in the selection dialog.
	apply_aspect = function(pos, asp_group, dst_aspgrp, dst_aspinfo)
		-- set the node to show the desired aspect
		-- called by advtrains when this signal's aspect group or the distant signal's aspect changes
		-- MAY return the aspect_info. If it returns nil then get_aspect_info will be queried at a later point.
	get_aspect_info(pos)
		-- Returns the aspect info table (main, shunt, dst etc.)W
}
]]

-- Set a signal's aspect.
-- Signal aspects should only be set through this function. It takes care of:
-- - Storing the main aspect and dst pos for this signal permanently (until next change)
-- - Assigning the distant signal for this signal
-- - Calling apply_aspect() in the signal's node definition to make the signal show the aspect
-- - Calling apply_aspect() again whenever the distant signal changes its aspect
-- - Notifying this signal's distant signals about changes to this signal (unless skip_dst_notify is specified)
function signal.set_aspect(pos, main_aspect, dst_pos, skip_dst_notify)
	-- TODO
end

-- Gets the stored main aspect and distant signal position for this signal
-- This information equals the information last passed to set_aspect
-- It does not take into consideration the actual speed signalling, please use
-- get_aspect_info() for this
-- returns: main_aspect, dst_pos
function signal.get_aspect(pos)
	--TODO
end

function signal.get_distant_signals_of(pos)
	--TODO
end

-- Called when either this signal has changed its main aspect
-- or when this distant signal's currently assigned main signal has changed its aspect
-- It retrieves the signal's main aspect and aspect info and calls apply_aspect of the node definition
-- to update the signal's appearance and aspect info
-- pts: The signal position to update as encoded_pos
function signal.reapply_aspect(pts, p_mainaspect)
	--TODO
end

-- Update this signal's aspect based on the set route
-- 
function signal.update_route_aspect(tcbs, skip_dst_notify)
	if tcbs.signal then
		local asp = tcbs.aspect or signal.MASP_HALT
		signal.set_aspect(tcbs.signal, asp, skip_dst_notify)
	end
end

function signal.can_dig(pos)
	return not advtrains.interlocking.db.get_sigd_for_signal(pos)
end

function advtrains.interlocking.signal_after_dig(pos)
	-- clear influence point
	advtrains.interlocking.signal_clear_aspect(pos)
	advtrains.distant.unassign_all(pos, true) -- TODO
end

-- Update waiting trains and distant signals about a changed signal aspect
function signal.notify_on_aspect_changed(pos, skip_dst_notify)
	--TODO update distant?
	local ipts, iconn = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if not ipts then return end
	local ipos = minetest.string_to_pos(ipts)

	-- FIXME: invalidate_all_paths_ahead does not appear to always work as expected
	--advtrains.invalidate_all_paths_ahead(ipos)
	minetest.after(0, advtrains.invalidate_all_paths, ipos)
end

function signal.on_rightclick(pos, node, player, itemstack, pointed_thing)
	local pname = player:get_player_name()
	local control = player:get_player_control()
	if control.aux1 then
		advtrains.interlocking.show_ip_form(pos, pname)
		return
	end
	advtrains.interlocking.show_signal_form(pos, node, pname)
end

function advtrains.interlocking.show_signal_form(pos, node, pname)
	local sigd = advtrains.interlocking.db.get_sigd_for_signal(pos)
	if sigd then
		advtrains.interlocking.show_signalling_form(sigd, pname)
	else
		local ndef = minetest.registered_nodes[node.name]
		if ndef.advtrains and ndef.advtrains.set_aspect then
			-- permit to set aspect manually
			local function callback(pname, aspect)
				signal.set_aspect(pos, aspect)
			end
			local isasp = advtrains.interlocking.signal_get_aspect(pos, node)

			advtrains.interlocking.show_signal_aspect_selector(
				pname,
				ndef.advtrains.supported_aspects,
				pos, callback,
				isasp)
		else
			--static signal - only IP
			advtrains.interlocking.show_ip_form(pos, pname)
		end
	end
end

local players_assign_ip = {}

local function ipmarker(ipos, connid)
	local node_ok, conns, rhe = advtrains.get_rail_info_at(ipos, advtrains.all_tracktypes)
	if not node_ok then return end
	local yaw = advtrains.dir_to_angle(conns[connid].c)

	-- using tcbmarker here
	local obj = minetest.add_entity(vector.add(ipos, {x=0, y=0.2, z=0}), "advtrains_interlocking:tcbmarker")
	if not obj then return end
	obj:set_yaw(yaw)
	obj:set_properties({
		textures = { "at_il_signal_ip.png" },
	})
end

function advtrains.interlocking.make_ip_formspec_component(pos, x, y, w)
	advtrains.interlocking.db.check_for_duplicate_ip(pos)
	local pts, connid = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if pts then
		return table.concat {
			F.S_label(x, y, "Influence point is set at @1.", string.format("%s/%s", pts, connid)),
			F.S_button_exit(x, y+0.5, w/2-0.125, "ip_set", "Modify"),
			F.S_button_exit(x+w/2+0.125, y+0.5, w/2-0.125, "ip_clear", "Clear"),
		}, pts, connid
	else
		return table.concat {
			F.S_label(x, y, "Influence point is not set."),
			F.S_button_exit(x, y+0.5, w, "ip_set", "Set influence point"),
		}
	end
end

-- shows small info form for signal properties
-- This function is named show_ip_form because it was originally only intended
-- for assigning/changing the influence point.
-- only_notset: show only if it is not set yet (used by signal tcb assignment)
function advtrains.interlocking.show_ip_form(pos, pname, only_notset)
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	local ipform, pts, connid = advtrains.interlocking.make_ip_formspec_component(pos, 0.5, 0.5, 7)
	local form = {
		"formspec_version[4]",
		"size[8,2.25]",
		ipform,
	}
	if pts then
		local ipos = minetest.string_to_pos(pts)
		ipmarker(ipos, connid)
	end
	if advtrains.distant.appropriate_signal(pos) then
		form[#form+1] = advtrains.interlocking.make_dst_formspec_component(pos, 0.5, 2, 7, 4.25)
		form[2] = "size[8,6.75]"
	end
	form = table.concat(form)
	if not only_notset or not pts then
		minetest.show_formspec(pname, "at_il_propassign_"..minetest.pos_to_string(pos), form)
	end
end

function advtrains.interlocking.handle_ip_formspec_fields(pname, pos, fields)
	if not (pos and minetest.check_player_privs(pname, {train_operator=true, interlocking=true})) then
		return
	end
	if fields.ip_set then
		advtrains.interlocking.signal_init_ip_assign(pos, pname)
	elseif fields.ip_clear then
		advtrains.interlocking.db.clear_ip_by_signalpos(pos)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local pts = string.match(formname, "^at_il_propassign_([^_]+)$")
	local pos
	if pts then
		pos = minetest.string_to_pos(pts)
	end
	if pos then
		advtrains.interlocking.handle_ip_formspec_fields(pname, pos, fields)
		advtrains.interlocking.handle_dst_formspec_fields(pname, pos, fields)
	end
end)

-- inits the signal IP assignment process
function signal.init_ip_assign(pos, pname)
	if not minetest.check_player_privs(pname, "interlocking") then
		minetest.chat_send_player(pname, "Insufficient privileges to use this!")
		return
	end
	--remove old IP
	--advtrains.interlocking.db.clear_ip_by_signalpos(pos)
	minetest.chat_send_player(pname, "Configuring Signal: Please look in train's driving direction and punch rail to set influence point.")
	
	players_assign_ip[pname] = pos
end

minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
	local pname = player:get_player_name()
	if not minetest.check_player_privs(pname, "interlocking") then
		return
	end
	-- IP assignment
	local signalpos = players_assign_ip[pname]
	if signalpos then
		if vector.distance(pos, signalpos)<=50 then
			local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
			if node_ok and #conns == 2 then
				
				local yaw = player:get_look_horizontal()
				local plconnid = advtrains.yawToClosestConn(yaw, conns)
				
				-- add assignment if not already present.
				local pts = advtrains.roundfloorpts(pos)
				if not advtrains.interlocking.db.get_ip_signal_asp(pts, plconnid) then
					advtrains.interlocking.db.set_ip_signal(pts, plconnid, signalpos)
					ipmarker(pos, plconnid)
					minetest.chat_send_player(pname, "Configuring Signal: Successfully set influence point")
				else
					minetest.chat_send_player(pname, "Configuring Signal: Influence point of another signal is already present!")
				end
			else
				minetest.chat_send_player(pname, "Configuring Signal: This is not a normal two-connection rail! Aborted.")
			end
		else
			minetest.chat_send_player(pname, "Configuring Signal: Node is too far away. Aborted.")
		end
		players_assign_ip[pname] = nil
	end
end)


advtrains.interlocking.signal = signal
