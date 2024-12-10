-- smartroute.lua
-- Implementation of the advtrains auto-route search

local atil = advtrains.interlocking
local ildb = atil.db
local sr = {}


-- Start the SmartRoute process. This searches for routes and tries to match them with existing routes, showing them in a form
function sr.start(pname, sigd)
	-- is start signal a shunt signal? This becomes default setting for searching_shunt
	local is_startsignal_shunt = false
	local tcbs = ildb.get_tcbs(sigd)
	if tcbs.signal then
		local ndef = advtrains.ndb.get_ndef(tcbs.signal)
		if ndef and ndef.advtrains then
			if ndef.advtrains.route_role == "shunt" then
				is_startsignal_shunt = true
			end
		end
	end
	sr.propose_next(pname, sigd, 10, is_startsignal_shunt) -- TODO set tscnt_limit to 2 initially and then increase it. Do this when form is implemented
end


local function otherside(s)
	if s==1 then return 2 else return 1 end
end

--route search implementation
-- Note this is similar to recursively_find_routes in database.lua, there used for the rscache

local function recursively_find_routes(s_pos, s_connid, searching_shunt, tcbseq, mark_pos, result_table, scan_limit, tscnt_limit)
	atdebug("(SmartRoute) Recursively restarting at ",s_pos, s_connid, "limit left", scan_limit,"tscnt",tscnt_limit)
	local ti = advtrains.get_track_iterator(s_pos, s_connid, scan_limit, false)
	local pos, connid, bconnid = ti:next_branch()
	pos, connid, bconnid = ti:next_track()-- step once to get ahead of previous turnout
	local last_pos
	repeat
		-- record position in mark_pos
		local pts = advtrains.encode_pos(pos)
		mark_pos[pts] = true
		
		local node = advtrains.ndb.get_node_or_nil(pos)
		--atdebug("(SmartRoute) Walk ",pos, "nodename", node.name, "entering at conn",bconnid)
		local ndef = minetest.registered_nodes[node.name]
		if ndef.advtrains and ndef.advtrains.node_state_map then
			-- Stop, this is a switchable node. Find out which conns we can go at
			atdebug("(SmartRoute) Found turnout ",pos, "nodename", node.name, "entering at conn",bconnid)
			local out_conns = ildb.get_possible_out_connids(node.name, bconnid)
			for oconnid, state in pairs(out_conns) do
				--atdebug("Going in direction",oconnid,"state",state)
				recursively_find_routes(pos, oconnid, searching_shunt,
					table.copy(tcbseq), table.copy(mark_pos),
					result_table, ti.limit, tscnt_limit)
			end
			return
		end
		--otherwise, this might be a tcb
		local tcb = ildb.get_tcb(pos)
		if tcb then
			local fsigd = { p = pos, s = connid }
			atdebug("(SmartRoute) Encounter TCB ",fsigd)
			tcbseq[#tcbseq+1] = fsigd
			-- check if this is a possible route endpoint
			local tcbs = tcb[connid]
			if tcbs.signal then
				local ndef = advtrains.ndb.get_ndef(tcbs.signal)
				if ndef and ndef.advtrains then
					if ndef.advtrains.route_role == "main" or ndef.advtrains.route_role == "main_distant"
							or ndef.advtrains.route_role == "end" or ndef.advtrains.route_role == "shunt" then
						-- signal is suitable target
						local is_mainsignal = ndef.advtrains.route_role ~= "shunt"
						-- record the found route in the results
						result_table[#result_table+1] = {
							tcbseq = table.copy(tcbseq),
							mark_pos = table.copy(mark_pos),
							shunt_route = not is_mainsignal,
							to_end_of_track = false,
							name = tcbs.signal_name or atil.sigd_to_string(fsigd)
						}
						-- if this is a main signal and/or we are only searching shunt routes, stop the search here
						if is_mainsignal or searching_shunt then
							atdebug("(SmartRoute) Terminating here because it is main or only shunt routes searched")
							return
						end
					end
				end
			end
			-- decrease tscnt
			tscnt_limit = tscnt_limit - 1
			atdebug("(SmartRoute) Remaining TS Count:",tscnt_limit)
			if tscnt_limit <= 0 then
				break
			end
		end
		-- Go forward
		last_pos = pos
		pos, connid, bconnid = ti:next_track()
	until not pos -- this stops the loop when either the track end is reached or the limit is hit
	atdebug("(SmartRoute) Reached track end or limit at", last_pos, ". This path is not saved, returning")
end

local function build_route_from_foundroute(froute, name)
	local route = {
		name = froute.name,
		use_rscache = true,
		smartroute_generated = true,
	}
	for _, sigd in ipairs(froute.tcbseq) do
		route[#route+1] = { next = sigd, locks = {} }
	end
	return route
end

-- Maximum scan length for track iterator
local TS_MAX_SCAN = 1000

function sr.rescan(pname, sigd, tscnt_limit, searching_shunt)
	local result_table = {}
	recursively_find_routes(sigd.p, sigd.s, is_startsignal_shunt, {}, {}, result_table, TS_MAX_SCAN, tscnt_limit)
	return result_table
end

-- Propose to pname the smartroute actions in a form, with the current settings as passed to this function
function sr.propose_next(pname, sigd, tscnt_limit, searching_shunt)
	local tcbs = ildb.get_tcbs(sigd)
	if not tcbs or not tcbs.routes then
		minetest.chat_send_player(pname, "Smartroute: TCBS or routes don't exist here!")
		return
	end
	-- Step 1: search for routes using the current settings
	local found_routes = sr.rescan(pname, sigd, tscnt_limit, searching_shunt)
	-- Step 2: remove routes for endpoints for which routes already exist
	local ex_endpts = {} -- key = sigd_to_string
	for rtid, route in ipairs(tcbs.routes) do
		local valid = advtrains.interlocking.check_route_valid(route, sigd)
		local endpoint = route[#route].next -- 'next' field of the last route segment (the segment with index==len)
		if valid and endpoint then
			local endstr = advtrains.interlocking.sigd_to_string(endpoint)
			atdebug("(Smartroute) Find existing endpoint:",route.name,"ends at",endstr)
			ex_endpts[endstr] = route.name
		else
			atdebug("(Smartroute) Find existing endpoint:",route.name," not considered, endpoint",endpoint,"valid",valid)
		end
	end
	local new_frte = {}
	for _,froute in ipairs(found_routes) do
		local endpoint = froute.tcbseq[#froute.tcbseq]
		local endstr = advtrains.interlocking.sigd_to_string(endpoint)
		if not ex_endpts[endstr] then
			new_frte[#new_frte+1] = froute
		else
			atdebug("(Smartroute) Throwing away",froute.name,"because endpoint",endstr,"already reached by route",ex_endpts[endstr])
		end
	end
	
	-- All remaining routes will be shown to user now.
	-- TODO: show a form. Right now still shortcircuit
	local sel_rte = #tcbs.routes+1
	for idx, froute in ipairs(new_frte) do
		tcbs.routes[#tcbs.routes+1] = build_route_from_foundroute(froute)
	end
	atdebug("Smartroute done!")
	advtrains.interlocking.show_signalling_form(sigd, pname, sel_rte)
end


advtrains.interlocking.smartroute = sr
