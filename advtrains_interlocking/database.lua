-- interlocking/database.lua
-- saving the location of TCB's, their neighbors and their state
--[[

== Route releasing (TORR) ==
A train passing through a route happens as follows:
Route set from entry to exit signal
Train passes entry signal and enters first TS past the signal
-> Route from signal cleared (TSs remain locked)
-> 'route' status of first TS past signal cleared
-> 'route_post' (holding the turnout locks) remains set
Train continues along the route.
Whenever train leaves a TS
-> Clearing any routes set from this TC outward recursively - see "Reversing problem"
-> Free turnout locks and clear 'route_post'
Whenever train enters a TS
-> Clear route status from the just entered TC (but not route_post)
Note that this prohibits by design that the train clears the route ahead of it.
== Reversing Problem ==
Encountered at the Royston simulation in SimSig. It is solved there by imposing a time limit on the set route. Call-on routes can somehow be set anyway.
Imagine this setup: (T=Train, R=Route, >=in_dir TCB)
    O-|  Royston P2 |-O
T->---|->RRR-|->RRR-|--
Train T enters from the left, the route is set to the right signal. But train is supposed to reverse here and stops this way:
    O-|  Royston P2 |-O
------|-TTTT-|->RRR-|--
The "Route" on the right is still set. Imposing a timeout here is a thing only professional engineers can determine, not an algorithm.
    O-|  Royston P2 |-O
<-T---|------|->RRR-|--
The train has left again, while route on the right is still set.
So, we have to clear the set route when the train has left the left TC.
This does not conflict with call-on routes, because both station tracks are set as "allow call-on"
Because none of the routes extends past any non-call-on sections, call-on route would be allowed here, even though the route
is locked in opposite direction at the time of routesetting.
Another case of this:
--TTT/--|->RRR--
The / here is a non-interlocked turnout (to a non-frequently used siding). For some reason, there is no exit node there,
so the route is set to the signal at the right end. The train is taking the exit to the siding and frees the TC, without ever
having touched the right TC.
]]--

local TRAVERSER_LIMIT = 1000


local ildb = {}

local track_circuit_breaks = {}
local track_sections = {}

-- Assignment of signals to TCBs
local signal_assignments = {}

-- track+direction -> signal position
local influence_points = {}

advtrains.interlocking.npr_rails = {}


function ildb.load(data)
	if not data then return end
	if data.tcbs then
		track_circuit_breaks = data.tcbs
	end
	if data.ts then
		track_sections = data.ts
	end
	if data.signalass then
		signal_assignments = data.signalass
	end
	if data.rs_locks then
		advtrains.interlocking.route.rte_locks = data.rs_locks
	end
	if data.rs_callbacks then
		advtrains.interlocking.route.rte_callbacks = data.rs_callbacks
	end
	if data.influence_points then
		influence_points = data.influence_points
	end
	if data.npr_rails then
		advtrains.interlocking.npr_rails = data.npr_rails
	end
	
	--COMPATIBILITY to Signal aspect format
	-- TODO remove in time...
	for pts,tcb in pairs(track_circuit_breaks) do
		for connid, tcbs in ipairs(tcb) do
			if tcbs.routes then
				for _,route in ipairs(tcbs.routes) do
					if route.aspect then
						-- transform the signal aspect format
						local asp = route.aspect
						if type(asp.main) == "table" then
							atwarn("Transforming route aspect of signal",pts,"/",connid,"")
							if asp.main.free then
								asp.main = asp.main.speed
							else
								asp.main = 0
							end
							if asp.dst.free then
								asp.dst = asp.dst.speed
							else
								asp.dst = 0
							end
							asp.proceed_as_main = asp.shunt.proceed_as_main
							asp.shunt = asp.shunt.free
							-- Note: info table not transferred, it's not used right now
						end
					end
				end
			end
		end
	end
end

function ildb.save()
	return {
		tcbs = track_circuit_breaks,
		ts=track_sections,
		signalass = signal_assignments,
		rs_locks = advtrains.interlocking.route.rte_locks,
		rs_callbacks = advtrains.interlocking.route.rte_callbacks,
		influence_points = influence_points,
		npr_rails = advtrains.interlocking.npr_rails,
	}
end

--
--[[
TCB data structure
{
-- This is the "A" side of the TCB
[1] = { -- Variant: with adjacent TCs.
	ts_id = <id> -- ID of the assigned track section
	signal = <pos> -- optional: when set, routes can be set from this tcb/direction and signal
	-- aspect will be set accordingly.
	routeset = <index in routes> -- Route set from this signal. This is the entry that is cleared once
	-- train has passed the signal. (which will set the aspect to "danger" again)
	route_committed = <boolean> -- When setting/requesting a route, routetar will be set accordingly,
	-- while the signal still displays danger and nothing is written to the TCs
	-- As soon as the route can actually be set, all relevant TCs and turnouts are set and this field
	-- is set true, clearing the signal
	aspect = <asp> -- The aspect the signal should show. If this is nil, should show the most restrictive aspect (red)
	signal_name = <string> -- The human-readable name of the signal, only for documenting purposes
	routes = { <route definition> } -- a collection of routes from this signal
	route_auto = <boolean> -- When set, we will automatically re-set the route (designated by routeset)
},
-- This is the "B" side of the TCB
[2] = { -- Variant: end of track-circuited area (initial state of TC)
	ts_id = nil, -- this is the indication for end_of_interlocking
	section_free = <boolean>, --this can be set by an exit node via mesecons or atlatc, 
	-- or from the tc formspec.
}
}

Track section
[id] = {
	name = "Some human-readable name"
	tc_breaks = { <signal specifier>,... } -- Bounding TC's (signal specifiers)
	-- Can be direct ends (auto-detected), conflicting routes or TCBs that are too far away from each other
	route = {
		origin = <signal>,  -- route origin
		entry = <sigd>,     -- supposed train entry point
		rsn = <string>,
		first = <bool>
	}
	route_post = {
		locks = {[n] = <pts>}
		next = <sigd>
	}
	-- Set whenever a route has been set through this TC. It saves the origin tcb id and side
	-- (=the origin signal). rsn is some description to be shown to the user
	-- first says whether to clear the routesetting status from the origin signal.
	-- locks contains the positions where locks are held by this ts.
	-- 'route' is cleared when train enters the section, while 'route_post' cleared when train leaves section.
	trains = {<id>, ...} -- Set whenever a train (or more) reside in this TC
}


Signal specifier (sigd) (a pair of TCB/Side):
{p = <pos>, s = <1/2>}

Signal Assignments: reverse lookup of signals assigned to TCBs
signal_assignments = {
[<signal pts>] = <sigd>
}
]]


--
function ildb.create_tcb(pos)
	local new_tcb = {
		[1] = {},
		[2] = {},
	}
	local pts = advtrains.roundfloorpts(pos)
	if not track_circuit_breaks[pts] then
		track_circuit_breaks[pts] = new_tcb
		return true
	else
		return false
	end
end

function ildb.get_tcb(pos)
	local pts = advtrains.roundfloorpts(pos)
	return track_circuit_breaks[pts]
end

function ildb.get_tcbs(sigd)
	local tcb = ildb.get_tcb(sigd.p)
	if not tcb then return nil end
	return tcb[sigd.s]
end


function ildb.create_ts(sigd)
	local tcbs = ildb.get_tcbs(sigd)
	local id = advtrains.random_id()
	
	while track_sections[id] do
		id = advtrains.random_id()
	end
	
	track_sections[id] = {
		name = "Section "..id,
		tc_breaks = { sigd }
	}
	tcbs.ts_id = id
end

function ildb.get_ts(id)
	return track_sections[id]
end



-- various helper functions handling sigd's
local sigd_equal = advtrains.interlocking.sigd_equal
local function insert_sigd_nodouble(list, sigd)
	for idx, cmp in pairs(list) do
		if sigd_equal(sigd, cmp) then
			return
		end
	end
	table.insert(list, sigd)
end


-- This function will actually handle the node that is in connid direction from the node at pos
-- so, this needs the conns of the node at pos, since these are already calculated
local function traverser(found_tcbs, pos, conns, connid, count, brk_when_found_n)
	local adj_pos, adj_connid, conn_idx, nextrail_y, next_conns = advtrains.get_adjacent_rail(pos, conns, connid, advtrains.all_tracktypes)
	if not adj_pos then
		--atdebug("Traverser found end-of-track at",pos, connid)
		return
	end
	-- look whether there is a TCB here
	if #next_conns == 2 then --if not, don't even try!
		local tcb = ildb.get_tcb(adj_pos)
		if tcb then
			-- done with this branch
			--atdebug("Traverser found tcb at",adj_pos, adj_connid)
			insert_sigd_nodouble(found_tcbs, {p=adj_pos, s=adj_connid})
			return
		end
	end
	-- recursion abort condition
	if count > TRAVERSER_LIMIT then
		--atdebug("Traverser hit counter at",adj_pos, adj_connid)
		return true
	end
	-- continue traversing
	local counter_hit = false
	for nconnid, nconn in ipairs(next_conns) do
		if adj_connid ~= nconnid then
			counter_hit = counter_hit or traverser(found_tcbs, adj_pos, next_conns, nconnid, count + 1, brk_when_found_n)
			if brk_when_found_n and #found_tcbs>=brk_when_found_n then
				break
			end
		end
	end
	return counter_hit
end



-- Merges the TS with merge_id into root_id and then deletes merge_id
local function merge_ts(root_id, merge_id)
	local rts = ildb.get_ts(root_id)
	local mts = ildb.get_ts(merge_id)
	if not mts then return end -- This may be the case when sync_tcb_neighbors
	-- inserts the same id twice. do nothing.
	
	if not ildb.may_modify_ts(rts) then return false end
	if not ildb.may_modify_ts(mts) then return false end
	
	-- cobble together the list of TCBs
	for _, msigd in ipairs(mts.tc_breaks) do
		local tcbs = ildb.get_tcbs(msigd)
		if tcbs then
			insert_sigd_nodouble(rts.tc_breaks, msigd)
			tcbs.ts_id = root_id
		end
		advtrains.interlocking.show_tcb_marker(msigd.p)
	end
	-- done
	track_sections[merge_id] = nil
end

local lntrans = { "A", "B" }
local function sigd_to_string(sigd)
	return minetest.pos_to_string(sigd.p).." / "..lntrans[sigd.s]
end

-- Check for near TCBs and connect to their TS if they have one, and syncs their data.
function ildb.sync_tcb_neighbors(pos, connid)
	local found_tcbs = { {p = pos, s = connid} }
	local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
	if not node_ok then
		atwarn("update_tcb_neighbors but node is NOK: "..minetest.pos_to_string(pos))
		return
	end
	
	--atdebug("Traversing from ",pos, connid)
	local counter_hit = traverser(found_tcbs, pos, conns, connid, 0)
	
	local ts_id
	local list_eoi = {}
	local list_ok = {}
	local list_mismatch = {}
	local ts_to_merge = {}
	
	for idx, sigd in pairs(found_tcbs) do
		local tcbs = ildb.get_tcbs(sigd)
		if not tcbs.ts_id then
			--atdebug("Sync: put",sigd_to_string(sigd),"into list_eoi")
			table.insert(list_eoi, sigd)
		elseif not ts_id and tcbs.ts_id then
			if not ildb.get_ts(tcbs.ts_id) then
				atwarn("Track section database is inconsistent, there's no TS with ID=",tcbs.ts_id)
				tcbs.ts_id = nil
				table.insert(list_eoi, sigd)
			else
				--atdebug("Sync: put",sigd_to_string(sigd),"into list_ok")
				ts_id = tcbs.ts_id
				table.insert(list_ok, sigd)
			end
		elseif ts_id and tcbs.ts_id and tcbs.ts_id ~= ts_id then
			atwarn("Track section database is inconsistent, sections share track!")
			atwarn("Merging",tcbs.ts_id,"into",ts_id,".")
			table.insert(list_mismatch, sigd)
			table.insert(ts_to_merge, tcbs.ts_id)
		end
	end
	if ts_id then
		local ts = ildb.get_ts(ts_id)
		for _, sigd in ipairs(list_eoi) do
			local tcbs = ildb.get_tcbs(sigd)
			tcbs.ts_id = ts_id
			table.insert(ts.tc_breaks, sigd)
			advtrains.interlocking.show_tcb_marker(sigd.p)
		end
		for _, mts in ipairs(ts_to_merge) do
			merge_ts(ts_id, mts)
		end
	end
end

function ildb.link_track_sections(merge_id, root_id)
	if merge_id == root_id then
		return
	end
	merge_ts(root_id, merge_id)
end

function ildb.remove_from_interlocking(sigd)
	local tcbs = ildb.get_tcbs(sigd)
	if not ildb.may_modify_tcbs(tcbs) then return false end
	
	if tcbs.ts_id then
		local tsid = tcbs.ts_id
		local ts = ildb.get_ts(tsid)
		if not ts then
			tcbs.ts_id = nil
			return true
		end
		
		-- remove entry from the list
		local idx = 1
		while idx <= #ts.tc_breaks do
			local cmp = ts.tc_breaks[idx]
			if sigd_equal(sigd, cmp) then
				table.remove(ts.tc_breaks, idx)
			else
				idx = idx + 1
			end
		end
		tcbs.ts_id = nil
		
		--ildb.sync_tcb_neighbors(sigd.p, sigd.s)
		
		if #ts.tc_breaks == 0 then
			track_sections[tsid] = nil
		end
	end
	advtrains.interlocking.show_tcb_marker(sigd.p)
	if tcbs.signal then
		return false
	end
	return true
end

function ildb.remove_tcb(pos)
	local pts = advtrains.roundfloorpts(pos)
	if not track_circuit_breaks[pts] then
		return true --FIX: not an error, because tcb is already removed
	end
	for connid=1,2 do
		if not ildb.remove_from_interlocking({p=pos, s=connid}) then
			return false
		end
	end
	track_circuit_breaks[pts] = nil
	return true
end

function ildb.dissolve_ts(ts_id)
	local ts = ildb.get_ts(ts_id)
	if not ildb.may_modify_ts(ts) then return false end
	local tcbr = advtrains.merge_tables(ts.tc_breaks)
	for _,sigd in ipairs(tcbr) do
		ildb.remove_from_interlocking(sigd)
	end
	-- Note: ts gets removed in the moment of the removal of the last TCB.
	return true
end

-- Returns true if it is allowed to modify any property of a track section, such as
-- - removing TCBs
-- - merging and dissolving sections
-- As of now the action will be denied if a route is set or if a train is in the section.
function ildb.may_modify_ts(ts)
	if ts.route or ts.route_post or (ts.trains and #ts.trains>0) then
		return false
	end
	return true
end


function ildb.may_modify_tcbs(tcbs)
	if tcbs.ts_id then
		local ts = ildb.get_ts(tcbs.ts_id)
		if ts and not ildb.may_modify_ts(ts) then
			return false
		end
	end
	return true
end

-- Utilize the traverser to find the track section at the specified position
-- Returns:
-- ts_id, origin - the first found ts and the sigd of the found tcb
-- nil - there were no TCBs in TRAVERSER_MAX range of the position
-- false - the first found TCB stated End-Of-Interlocking, or track ends were reached
function ildb.get_ts_at_pos(pos)
	local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
	if not node_ok then
		error("get_ts_at_pos but node is NOK: "..minetest.pos_to_string(pos))
	end
	local limit_hit = false
	local found_tcbs = {}
	for connid, conn in ipairs(conns) do -- Note: a breadth-first-search would be better for performance
		limit_hit = limit_hit or traverser(found_tcbs, pos, conns, connid, 0, 1)
		if #found_tcbs >= 1 then
			local tcbs = ildb.get_tcbs(found_tcbs[1])
			local ts
			if tcbs.ts_id then
				return tcbs.ts_id, found_tcbs[1]
			else
				return false
			end
		end
	end
	if limit_hit then
		-- there was at least one limit hit
		return nil
	else
		-- all traverser ends were track ends
		return false
	end
end


-- returns the sigd the signal at pos belongs to, if this is known
function ildb.get_sigd_for_signal(pos)
	local pts = advtrains.roundfloorpts(pos)
	local sigd = signal_assignments[pts]
	if sigd then
		if not ildb.get_tcbs(sigd) then
			signal_assignments[pts] = nil
			return nil
		end
		return sigd
	end
	return nil
end
function ildb.set_sigd_for_signal(pos, sigd)
	local pts = advtrains.roundfloorpts(pos)
	signal_assignments[pts] = sigd
end

-- checks if there's any influence point set to this position
-- if purge is true, checks whether the associated signal still exists
-- and deletes the ip if not.
function ildb.is_ip_at(pos, purge)
	local pts = advtrains.roundfloorpts(pos)
	if influence_points[pts] then
		if purge then
			-- is there still a signal assigned to it?
			for connid, sigpos in pairs(influence_points[pts]) do
				local asp = advtrains.interlocking.signal_get_aspect(sigpos)
				if not asp then
					atlog("Clearing orphaned signal influence point", pts, "/", connid)
					ildb.clear_ip_signal(pts, connid)
				end
			end
			-- if there's no side left after purging, return false
			if not influence_points[pts] then return false end
		end
		return true
	end
	return false
end

-- checks if a signal is influencing here
function ildb.get_ip_signal(pts, connid)
	if influence_points[pts] then
		return influence_points[pts][connid]
	end
end

-- Tries to get aspect to obey here, if there
-- is a signal ip at this location
-- auto-clears invalid assignments
function ildb.get_ip_signal_asp(pts, connid)
	local p = ildb.get_ip_signal(pts, connid)
	if p then
		local asp = advtrains.interlocking.signal_get_aspect(p)
		if not asp then
			atlog("Clearing orphaned signal influence point", pts, "/", connid)
			ildb.clear_ip_signal(pts, connid)
			return nil
		end
		return asp, p
	end
	return nil
end

-- set signal assignment.
function ildb.set_ip_signal(pts, connid, spos)
	ildb.clear_ip_by_signalpos(spos)
	if not influence_points[pts] then
		influence_points[pts] = {}
	end
	influence_points[pts][connid] = spos
end
-- clear signal assignment.
function ildb.clear_ip_signal(pts, connid)
	influence_points[pts][connid] = nil
	for _,_ in pairs(influence_points[pts]) do
		return
	end
	influence_points[pts] = nil
end

function ildb.get_ip_by_signalpos(spos)
	for pts,tab in pairs(influence_points) do
		for connid,pos in pairs(tab) do
			if vector.equals(pos, spos) then
				return pts, connid
			end
		end
	end
end
function ildb.check_for_duplicate_ip(spos)
	local main_ip_found = false
	-- first pass: check for duplicates
	for pts,tab in pairs(influence_points) do
		for connid,pos in pairs(tab) do
			if vector.equals(pos, spos) then
				if main_ip_found then
					atwarn("Signal at",spos,": Deleting duplicate signal influence point at",pts,"/",connid)
					tab[connid] = nil
				end
				main_ip_found = true
			end
		end
	end
	-- second pass: delete empty tables
	for pts,tab in pairs(influence_points) do
		if not tab[1] and not tab[2] then -- only those two connids may exist
			influence_points[pts] = nil
		end
	end
end

-- clear signal assignment given the signal position
function ildb.clear_ip_by_signalpos(spos)
	local pts, connid = ildb.get_ip_by_signalpos(spos)
	if pts then ildb.clear_ip_signal(pts, connid) end
end


advtrains.interlocking.db = ildb




