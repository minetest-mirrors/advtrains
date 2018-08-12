-- Setting and clearing routes

-- TODO duplicate
local lntrans = { "A", "B" }
local function sigd_to_string(sigd)
	return minetest.pos_to_string(sigd.p).." / "..lntrans[sigd.s]
end

local ildb = advtrains.interlocking.db
local ilrs = {}

-- table containing locked points
-- also manual locks (maintenance a.s.o.) are recorded here
-- [pts] = { 
--		[n] = { [by = <ts_id>], rsn = <human-readable text>, [origin = <sigd>] }
--	}
ilrs.rte_locks = {}
ilrs.rte_callbacks = {
	ts = {},
	lck = {}
}

-- Requests the given route
-- This function will try to set the designated route.
-- If this is not possible, route is inserted in the subscriber list for
-- the problematic lock points
function ilrs.request_route(signal, tcbs, routeid)
	
end

-- main route setting. First checks if everything can be set as designated,
-- then (if "try" is not set) actually sets it
-- returns:
-- true - route can be/was successfully set
-- false, message, cbts, cblk - something went wrong, what is contained in the message.
-- cbts: the ts id of the conflicting ts, cblk: the pts of the conflicting component
function ilrs.set_route(signal, route, try)
	if not try then
		local tsuc, trsn, cbts, cblk = ilrs.set_route(signal, route, true)
		if not tsuc then
			return false, trsn, cbts, cblk
		end
	end
	
	-- we start at the tc designated by signal
	local c_sigd = signal
	local first = true
	local i = 1
	local rtename = route.name
	local signalname = ildb.get_tcbs(signal).signal_name
	local c_tcbs, c_ts_id, c_ts, c_rseg, c_lckp
	while c_sigd and i<=#route do
		c_tcbs = ildb.get_tcbs(c_sigd)
		c_ts_id = c_tcbs.ts_id
		if not c_ts_id then
			if not try then atwarn("Encountered End-Of-Interlocking while setting route",rtename,"of",signal) end
			return false, "No track section adjacent to "..sigd_to_string(c_sigd)..". Please reconfigure route!"
		end
		c_ts = ildb.get_ts(c_ts_id)
		c_rseg = route[i]
		c_lckp = {}
		
		if c_ts.route then
			if not try then atwarn("Encountered ts lock during a real run of routesetting routine, at ts=",c_ts_id,"while setting route",rtename,"of",signal) end
			return false, "Section '"..c_ts.name.."' already has route set from "..sigd_to_string(c_ts.route.origin).."!", c_ts_id, nil
		end
		if c_ts.trains and #c_ts.trains>0 then
			if not try then atwarn("Encountered ts occupied during a real run of routesetting routine, at ts=",c_ts_id,"while setting route",rtename,"of",signal) end
			return false, "Section '"..c_ts.name.."' is occupied!", c_ts_id, nil
		end
		
		for pts, state in pairs(c_rseg.locks) do
			local confl = ilrs.has_route_lock(pts, state)
			
			local pos = minetest.string_to_pos(pts)
			local node = advtrains.ndb.get_node(pos)
			local ndef = minetest.registered_nodes[node.name]
			if ndef and ndef.luaautomation and ndef.luaautomation.setstate and ndef.luaautomation.getstate then
				local cstate = ndef.luaautomation.getstate
				if type(cstate)=="function" then cstate = cstate(pos) end
				if cstate ~= state then
					local confl = ilrs.has_route_lock(pts)
					if confl then
						if not try then atwarn("Encountered route lock while a real run of routesetting routine, at position",pts,"while setting route",rtename,"of",signal) end
						return false, "Lock conflict at "..pts..", Held locked by:\n"..confl, nil, pts
					elseif not try then
						ndef.luaautomation.setstate(pos, state)
					end
				end
				if not try then
					ilrs.add_route_lock(pts, c_ts_id, "Route '"..rtename.."' from signal '"..signalname.."'", signal)
					c_lckp[#c_lckp+1] = pts
				end
			else
				if not try then atwarn("Encountered route lock misconfiguration (no passive component) while a real run of routesetting routine, at position",pts,"while setting route",rtename,"of",signal) end
				return false, "No passive component at "..pts..". Please reconfigure route!"
			end
		end
		-- reserve ts and write locks
		if not try then
			c_ts.route = {
				origin = signal,
				entry = c_sigd,
				rsn = "Route '"..rtename.."' from signal '"..signalname.."', segment #"..i,
				first = first,
			}
			c_ts.route_post = {
				locks = c_lckp,
				next = c_rseg.next,
			}
		end
		-- advance
		first = nil
		c_sigd = c_rseg.next
		i = i + 1
	end
	
	return true
end

-- Checks whether there is a route lock that prohibits setting the component
-- to the wanted state. returns string with reasons on conflict
function ilrs.has_route_lock(pts)
	-- look this up
	local e = ilrs.rte_locks[pts]
	if not e then return nil
	elseif #e==0 then
		ilrs.rte_locks[pts] = nil
		return nil
	end
	local txts = {}
	for _, ent in ipairs(e) do
		txts[#txts+1] = ent.rsn
	end
	return table.concat(txts, "\n")
end

-- adds route lock for position
function ilrs.add_route_lock(pts, ts, rsn, origin)
	ilrs.free_route_locks_indiv(pts, ts, true)
	local elm = {by=ts, rsn=rsn, origin=origin}
	if not ilrs.rte_locks[pts] then
		ilrs.rte_locks[pts] = { elm }
	else
		table.insert(ilrs.rte_locks[pts], elm)
	end
end

-- adds route lock for position
function ilrs.add_manual_route_lock(pts, rsn)
	local elm = {rsn=rsn}
	if not ilrs.rte_locks[pts] then
		ilrs.rte_locks[pts] = { elm }
	else
		table.insert(ilrs.rte_locks[pts], elm)
	end
end

-- frees route locking for all points (components) that were set by this ts
function ilrs.free_route_locks(ts, lcks, nocallbacks)
	for _,pts in pairs(lcks) do
		ilrs.free_route_locks_indiv(pts, ts, nocallbacks)
	end
end

function ilrs.free_route_locks_indiv(pts, ts, nocallbacks)
	local e = ilrs.rte_locks[pts]
	if not e then return nil
	elseif #e==0 then
		ilrs.rte_locks[pts] = nil
		return nil
	end
	local i = 1
	while i <= #e do
		if e[i].by == ts then
			atdebug("free_route_locks_indiv",pts,"clearing entry",e[i].by,e[i].rsn)
			table.remove(e,i)
		else
			i = i + 1
		end
	end
	-- This must be delayed, because this code is executed in-between a train step
	-- TODO use luaautomation timers?
	minetest.after(0, ilrs.update_waiting, "lck", pts)
end
-- frees all route locks, even manual ones set with the tool, at a specific position
function ilrs.remove_route_locks(pts, nocallbacks)
	ilrs.rte_locks[pts] = nil
	--TODO callbacks
end

local function sigd_equal(sigd, cmp)
	return vector.equals(sigd.p, cmp.p) and sigd.s==cmp.s
end

-- starting from the designated sigd, clears all subsequent route and route_post
-- information from the track sections.
-- note that this does not clear the routesetting status from the entry signal,
-- only from the ts's
function ilrs.cancel_route_from(sigd)
	-- we start at the tc designated by signal
	local c_sigd = sigd
	local c_tcbs, c_ts_id, c_ts, c_rseg, c_lckp
	while c_sigd do
		c_tcbs = ildb.get_tcbs(c_sigd)
		c_ts_id = c_tcbs.ts_id
		c_ts = ildb.get_ts(c_ts_id)
		
		if not c_ts
			or not c_ts.route
			or not sigd_equal(c_ts.route.entry, c_sigd) then
			return
		end
		
		c_ts.route = nil
		
		if c_ts.route_post then
			advtrains.interlocking.route.free_route_locks(c_ts_id, c_ts.route_post.locks)
			c_sigd = c_ts.route_post.next
		else
			c_sigd = nil
		end
		c_ts.route_post = nil
		minetest.after(0, advtrains.interlocking.route.update_waiting, "ts", c_ts_id)
	end
end

local asp_generic_free = {
	main = {
		free = true,
		speed = 100,
	},
	shunt = {
		free = false,
	},
	dst = {
		free = true,
		speed = 100,
	},
	info = {}
}

-- TCBS Routesetting helper: generic update function for
-- route setting

function ilrs.update_route(sigd, tcbs, newrte, cancel)
	-- in general, always show danger signal
	tcbs.aspect = nil
	if (newrte and tcbs.routeset and tcbs.routeset ~= newrte) or cancel then
		if tcbs.route_committed then
			atdebug("Cancelling:",tcbs.routeset)
			advtrains.interlocking.route.cancel_route_from(sigd)
		end
		tcbs.route_committed = nil
		tcbs.routeset = newrte
	end
	if newrte or tcbs.routeset then
		if newrte then tcbs.routeset = newrte end
		atdebug("Setting:",tcbs.routeset)
		local succ, rsn, cbts, cblk = ilrs.set_route(sigd, tcbs.routes[tcbs.routeset])
		if not succ then
			tcbs.route_rsn = rsn
			atdebug("Routesetting failed:",rsn)
			-- add cbts or cblk to callback table
			if cbts then
				atdebug("cbts =",cbts)
				if not ilrs.rte_callbacks.ts[cbts] then ilrs.rte_callbacks.ts[cbts]={} end
				advtrains.insert_once(ilrs.rte_callbacks.ts[cbts], sigd, sigd_equal)
			end
			if cblk then
				atdebug("cblk =",cblk)
				if not ilrs.rte_callbacks.lck[cblk] then ilrs.rte_callbacks.lck[cblk]={} end
				advtrains.insert_once(ilrs.rte_callbacks.lck[cblk], sigd, sigd_equal)
			end
		else
			atdebug("Committed Route:",tcbs.routeset)
			tcbs.route_committed = true
			tcbs.route_rsn = false
			tcbs.aspect = asp_generic_free
		end
	end
	advtrains.interlocking.update_signal_aspect(tcbs)
end

-- Try to re-set routes that conflicted with this point
-- sys can be one of "ts" and "lck"
-- key is then ts_id or pts respectively
function ilrs.update_waiting(sys, key)
	atdebug("update_waiting:",sys,".",key)
	local t = ilrs.rte_callbacks[sys][key]
	ilrs.rte_callbacks[sys][key] = nil
	if t then
		for _,sigd in ipairs(t) do
			atdebug("Updating", sigd)
			-- While these are run, the table we cleared before may be populated again, which is in our interest.
			-- (that's the reason we needed to copy it)
			local tcbs = ildb.get_tcbs(sigd)
			if tcbs then
				ilrs.update_route(sigd, tcbs)
			end
		end
	end
end

advtrains.interlocking.route = ilrs
