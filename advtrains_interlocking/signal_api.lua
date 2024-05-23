-- Signal API implementation

local F = advtrains.formspec

local signal = {}

signal.MASP_HALT = {
	name = "_halt",
	speed = 0,
	halt = true,
	remote = nil,
}

signal.MASP_FREE = {
	name = "_default",
	speed = -1,
	remote = nil,
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
- A Ks signal has the main_aspect="proceed_12" set for a route
- The signal at the end of the route shows main_aspect="proceed_8", advtrains also passes on that this means {main=8, shunt=false}
- The ndef.afunction(pos, node, main_aspect, rem_aspect, rem_aspinfo) determines that the signal should now show
		blinking green with main indicator 12 and dst indicator 8, and sets the nodes accordingly.
		This function can now return the Aspect Info table, which will be cached by advtrains until the aspect changes again
		and will be used when a train approaches the signal. If nil is returned, then the aspect will be queried next time
		by calling ndef.advtrains.get_aspect_info(pos)

Note that once apply_aspect returns, there is no need for advtrains anymore to query the aspect info.
When the signal, for any reason, wants to change its aspect by itself *without* going through the signal API then
it should update the aspect info cache by calling advtrains.interlocking.signal.update_aspect_info(pos)

Apply_aspect may also receive the special main aspect { name = "_halt", halt = true }. It usually means that the signal is not assigned to anything particular,
and it should cause the signal to show its most restrictive aspect. Typically it is a halt aspect, but e.g. for distant-only
signals this would be "expect stop".

A special case occurs for pure distant signals: Such signals must set apply_aspect, but must not set main_aspects. Behavior is as follows:
- Signal is uninitialized, distant signal is not assigned to a main signal, or no route is set: main_aspect == { name = "_halt", halt = true } and rem_aspect == nil
- A remote main signal is assigned (either by user or by route): main_aspect is always { name = "_default" } and rem_aspect / rem_aspinfo give the correct information

Main aspect names starting with underscore (e.g. "_default") are reserved and must not be used!

== Aspect Info ==
The actual signal aspect in the already-known format. This is what the trains use to determine halt/proceed and speed.
asp = {
	main = 0 (halt) / -1 (max speed) / false (no info) / <number> (speed limit)
	shunt = true (shunt free) / false (shunt not free)
	proceed_as_main = true (shunt move can proceed and become train move when main!=0) / false (no)
	dst = speed of the remote signal (like main, informative character, not actually used)
}

Node definition of signals:
- The signal needs some logic to figure out, for each combination of its own aspect group and the distant signal's aspect, what aspect info it can/will show.
ndef.advtrains = {
	main_aspects = {
		{ name = "proceed" description = "Proceed at full speed", <more data at discretion of signal>}
		{ name = "reduced" description = "Proceed at reduced speed", <more data at discretion of signal>}
	}
		-- This list is mainly for the selection dialog. Order of entries determines list order in the dropdown.
		-- Some fields have special meaning:
		-- name: A unique key to identify the main aspect. Only this key is saved, but APIs always receive the whole table
		-- description: Text shown in UI dropdown
		-- speed: a number. When present, a speed field is shown in the UI next to the dropdown (prefilled with the value).
		--		When user selects a different speed there, this different speed replaces the value in the table whenever the main_aspect is applied.
		-- Node can set any other fields at its discretion. They are not touched.
		-- Note: On first call advtrains automatically inserts into the ndef.advtrains table a main_aspects_lookup hashtable
		-- Note: Pure distant signals (that cannot show halt) should NOT have a main_aspects table
	apply_aspect = function(pos, node, main_aspect, rem_aspect, rem_aspinfo)
		-- set the node to show the desired aspect
		-- called by advtrains when this signal's aspect group or the remote signal's aspect changes
		-- main_aspect is never nil, but can be one of the special aspects { name = "_halt", halt = true } or { name = "_default" }
		-- MAY return the aspect_info. If it returns nil then get_aspect_info will be queried at a later point.
	get_aspect_info(pos, main_aspect)
		-- Returns the aspect info table (main, shunt, dst etc.)
	distant_support = true or false
		-- If true, signal is considered in distant signalling. If false or nil, rem_aspect and rem_aspinfo are never set.
	route_role = one of "main", "shunt", "distant", "distant_repeater", "end"
		-- Determines how the signal behaves when routes are set. Only in effect when signal is assigned to a TCB.
		-- main: The signal is a possible endpoint for a train move route. Distant signals before it refer to it.
		-- shunt: The signal is a possible endpoint for a shunt move route. Ignored for distant signals.
		-- distant, distant_repeater: When route is set, signal is always assigned its first main aspect. The next signal with role="main" is set as the remote signal. (currently no further distinction)
		-- end: like main, but signifies that it marks an end of track and trains cannot continue further. (currently no practical implications above main)
}

== Nomenclature ==
The distant/main relation is named as follows:
     V    M
=====>====>
Main signal (main) always refers to the signal that is in focus right now (even if that is a distant-only signal)
From the standpoint of M, V is the distant (dst) signal. M does not need to concern itself with V's aspect but needs to notify V when it changes
From the standpoint of V, M is the remote (rem) signal. V needs to show an aspect that matches its remote signal M

== Criteria for which signals are eligible for routes ==

All signals must define:
- get_aspect_info()

Signals that can be assigned to a TCB must satisfy:
- apply_aspect() defined

Signals that are possible start and end points for a route must satisfy:
- main_aspects defined (note, pure distant signals should therefore not define main_aspects)

]]

-- Database
-- Signal Aspect store
-- Stores for each signal the main aspect and other info, like the assigned remote signal
-- [signal encodePos] = { name = "proceed", [speed = 12], [remote = encodedPos] }
signal.aspects = {}

-- Distant signal notification. Records for each signal the distant signals that refer to it
-- Note: this mapping is weak. Needs always backreference check.
-- [signal encodePos] = { [distant signal encodePos] = true }
signal.distant_refs = {}

function signal.load(data)
	signal.aspects = data.aspects or {}
	-- rebuild distant_refs after load
	signal.distant_refs = {}
	for main, aspt in pairs(signal.aspects) do
		if aspt.remote then
			if not signal.distant_refs[aspt.remote] then
				signal.distant_refs[aspt.remote] = {}
			end
			signal.distant_refs[aspt.remote][main] = true
		end
	end
end

function signal.save(data)
	data.aspects = signal.aspects
end


-- Set a signal's aspect.
-- Signal aspects should only be set through this function. It takes care of:
-- - Storing the main aspect and dst pos for this signal permanently (until next change)
-- - Assigning the distant signal for this signal
-- - Calling apply_aspect() in the signal's node definition to make the signal show the aspect
-- - Calling apply_aspect() again whenever the remote signal changes its aspect
-- - Notifying this signal's distant signals about changes to this signal (unless skip_dst_notify is specified)
function signal.set_aspect(pos, main_asp_name, main_asp_speed, rem_pos, skip_dst_notify)
	local main_pts = advtrains.encode_pos(pos)
	local old_tbl = signal.aspects[main_pts]
	local old_remote = old_tbl and old_tbl.remote
	local new_remote = rem_pos and advtrains.encode_pos(rem_pos)
	
	-- if remote has changed, unregister from old remote
	if old_remote and old_remote~=new_remote and signal.distant_refs[old_remote] then
		atdebug("unregister old remote: ",old_remote,"from",main_pts)
		signal.distant_refs[old_remote][main_pts] = nil
	end
		
	signal.aspects[main_pts] = { name = main_asp_name, speed = main_asp_speed, remote = new_remote }
	-- apply aspect on main signal, this also checks new_remote
	signal.reapply_aspect(main_pts)	
	
	-- notify my distants about this change (with limit 2)
	if not skip_dst_notify then
		signal.notify_distants_of(main_pts, 2)
	end
end

function signal.clear_aspect(pos, skip_dst_notify)
	local main_pts = advtrains.encode_pos(pos)
	local old_tbl = signal.aspects[main_pts]
	local old_remote = old_tbl and old_tbl.remote
	
	-- unregister from old remote
	if old_remote then
		signal.distant_refs[old_remote][main_pts] = nil
	end
		
	signal.aspects[main_pts] = nil
	-- apply aspect on main signal, this also checks new_remote
	signal.reapply_aspect(main_pts)	
	
	-- notify my distants about this change (with limit 2)
	if not skip_dst_notify then
		signal.notify_distants_of(main_pts, 2)
	end
end

-- Notify distant signals of main_pts of a change in the aspect of this signal
-- 
function signal.notify_distants_of(main_pts, limit)
	atdebug("notify_distants_of",advtrains.decode_pos(main_pts),"limit",limit)
	if limit <= 0 then
		return
	end
	local dstrefs = signal.distant_refs[main_pts]
	atdebug("dstrefs",dstrefs,"")
	if dstrefs then
		for dst,_ in pairs(dstrefs) do
			-- ensure that the backref is still valid
			local dst_asp = signal.aspects[dst]
			if dst_asp and dst_asp.remote == main_pts then
				signal.reapply_aspect(dst)
				signal.notify_distants_of(dst, limit - 1)
			else
				atwarn("Distant signal backref is not purged: main =",main_pts,", distant =",dst,", remote =",dst_asp.remote,"")
			end
		end
	end
end

function signal.notify_trains(pos)
	local ipts, iconn = advtrains.interlocking.db.get_ip_by_signalpos(pos)
	if not ipts then return end
	local ipos = minetest.string_to_pos(ipts)

	-- FIXME: invalidate_all_paths_ahead does not appear to always work as expected
	--advtrains.invalidate_all_paths_ahead(ipos)
	minetest.after(0, advtrains.invalidate_all_paths, ipos)
end

-- Update waiting trains and distant signals about a changed signal aspect
-- Must be called when a signal's aspect changes through some other means
-- and not via the signal mechanism
function signal.notify_on_aspect_changed(pos, skip_dst_notify)
	signal.notify_trains(pos)
	if not skip_dst_notify then
		signal.notify_distants_of(advtrains.encode_pos(pos), 2)
	end
end

-- Gets the stored main aspect and distant signal position for this signal
-- This information equals the information last passed to set_aspect
-- It does not take into consideration the actual speed signalling, please use
-- get_aspect_info() for this
-- pos: the position of the signal
-- returns: main_aspect, dst_pos
function signal.get_aspect(pos)
	local aspt = signal.aspects[advtrains.encode_pos(pos)]
	local ma,dp = signal.get_aspect_internal(pos, aspt)
	return ma, advtrains.decode_pos(dp)
end

local function cache_mainaspects(ndefat)
	ndefat.main_aspects_lookup = {}
	for _,ma in ipairs(ndefat.main_aspects) do
		ndefat.main_aspects_lookup[ma.name] = ma
	end
end

function signal.get_aspect_internal(pos, aspt)
	atdebug("get_aspect_internal",pos,aspt)
	-- look aspect in nodedef
	local node = advtrains.ndb.get_node_or_nil(pos)
	local ndef = node and minetest.registered_nodes[node.name]
	if not aspt then
		-- oh, no main aspect, nevermind
		return signal.MASP_HALT, nil, node, ndef
	end
	local ndefat = ndef and ndef.advtrains
	if ndefat and ndefat.apply_aspect then
		-- only if signal defines main aspect and its set in aspt
		if ndefat.main_aspects and aspt.name then
			if not ndefat.main_aspects_lookup then
				cache_mainaspects(ndefat)
			end
			local masp = ndefat.main_aspects_lookup[aspt.name]
			-- special handling for the default free aspect ("_default")
			if aspt.name == "_default" then
				masp = ndefat.main_aspects[1]
			end
			if not masp then
				atwarn(pos,"invalid main aspect",aspt.name,"valid are",ndefat.main_aspects_lookup)
				return signal.MASP_HALT, aspt.remote, node, ndef
			end
			-- if speed, then apply speed
			if masp.speed and aspt.speed then
				masp = table.copy(masp)
				masp.speed = aspt.speed
			end
			return masp, aspt.remote, node, ndef
		elseif aspt.name then
			-- Distant-only signal, still supports kind of default aspect
			return { name = aspt.name, speed = aspt.speed }, aspt.remote, node, ndef
		end
	end
	-- invalid node or no main aspect, return default halt aspect for masp
	return signal.MASP_HALT, aspt.remote, node, ndef
end

-- For the signal at pos, get the "aspect info" table. This contains the speed signalling information at this location
function signal.get_aspect_info(pos)
	-- get aspect internal
	local aspt = signal.aspects[advtrains.encode_pos(pos)]
	local masp, remote, node, ndef = signal.get_aspect_internal(pos, aspt)
	-- call into ndef
	if ndef.advtrains and ndef.advtrains.get_aspect_info then
		local ai = ndef.advtrains.get_aspect_info(pos, masp)
		atdebug(pos,"aspectinfo",ai)
		return ai
	end
end


-- Called when either this signal has changed its main aspect
-- or when this distant signal's currently assigned main signal has changed its aspect
-- It retrieves the signal's main aspect and aspect info and calls apply_aspect of the node definition
-- to update the signal's appearance and aspect info
-- pts: The signal position to update as encoded_pos
-- returns: the return value of the nodedef call which may be aspect_info
function signal.reapply_aspect(pts)
	-- get aspt
	local aspt = signal.aspects[pts]
	atdebug("reapply_aspect",advtrains.decode_pos(pts),"aspt",aspt)
	local pos = advtrains.decode_pos(pts)
	if not aspt then
		signal.notify_trains(pos)
		return -- oop, nothing to do
	end
	-- resolve mainaspect table by name
	local masp, remote, node, ndef = signal.get_aspect_internal(pos, aspt)
	-- if we have remote, resolve remote
	local rem_masp, rem_aspi
	if remote then
		-- register in remote signal as distant
		if not signal.distant_refs[remote] then
			signal.distant_refs[remote] = {}
		end
		signal.distant_refs[remote][pts] = true
		local rem_aspt = signal.aspects[remote]
		atdebug("resolving remote",advtrains.decode_pos(remote),"aspt",rem_aspt)
		if rem_aspt and rem_aspt.name then
			local rem_pos = advtrains.decode_pos(remote)
			rem_masp, _, _, rem_ndef = signal.get_aspect_internal(rem_pos, rem_aspt)
			if rem_masp then
				if rem_ndef.advtrains and rem_ndef.advtrains.get_aspect_info then
					rem_aspi = rem_ndef.advtrains.get_aspect_info(rem_pos, rem_masp)
				end
			end
		end
	end
	-- call into ndef
	atdebug("applying to",pos,": main_asp",masp,"rem_masp",rem_masp,"rem_aspi",rem_aspi)
	if ndef.advtrains and ndef.advtrains.apply_aspect then
		ndef.advtrains.apply_aspect(pos, node, masp, rem_masp, rem_aspi)
	end
	-- notify trains
	signal.notify_trains(pos)
end

-- Update this signal's aspect based on the set route
-- 
function signal.update_route_aspect(tcbs, skip_dst_notify)
	if tcbs.signal then
		local asp = tcbs.aspect or signal.MASP_HALT
		signal.set_aspect(tcbs.signal, asp.name, asp.speed, asp.remote, skip_dst_notify)
	end
end

-- Returns how capable the signal is with regards to aspect setting
-- 0: not a signal at all
-- 1: signal has get_aspect_info() but the aspect is not variable (e.g. a sign)
-- 2: signal has apply_aspect() but does not have main aspects (e.g. a pure distant signal)
-- 3: Full capabilities, signal has main aspects and can be used as main/shunt signal (can be start/endpoint of a route)
function signal.get_signal_cap_level(pos)
	local node = advtrains.ndb.get_node_or_nil(pos)
	local ndef = node and minetest.registered_nodes[node.name]
	local ndefat = ndef and ndef.advtrains
	if ndefat and ndefat.get_aspect_info then
		if ndefat.apply_aspect  then
			if ndefat.main_aspects then
				return 3
			end
			return 2
		end
		return 1
	end
	return 0
end

----------------

function signal.can_dig(pos)
	return not advtrains.interlocking.db.get_sigd_for_signal(pos)
end

function signal.after_dig(pos)
	-- TODO clear influence point
	advtrains.interlocking.signal.clear_aspect(pos)
end

function signal.on_rightclick(pos, node, player, itemstack, pointed_thing)
	local pname = player:get_player_name()
	local control = player:get_player_control()
	advtrains.interlocking.show_signal_form(pos, node, pname, control.aux1)
end

advtrains.interlocking.signal = signal
