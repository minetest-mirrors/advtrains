-- ars.lua
-- automatic routesetting

--[[
	The "ARS table" and its effects:
	Every route has (or can have) an associated ARS table:
	ars = {
		[n] = {
			ln = "<line>"			-- either line
			rc = "<routingcode>"  -- or routingcode
			n = true/false -- true = logical not (matches everything that does not have this line/rc)
			conj = { -- and conjunction, optional. This must be true in addition to the main rule
				ln=... / rc=... / n=... -- like toplevel
				conj=... -- can be nested
						-- note that conj cannot have prio, in inherits the prio from main rule
			}
			prio = <num> -- optional, a priority number. If set, enables "multi-ARS" where train can wait for multiple routes at once
			-- or
			c="<a comment>"
		}
		default = true -- Route is the default route for trains
		default_prio -- optional, priority for multi-ars with default route
		default_conj = {...} -- optional, conditions (conjunction) that need to be fulfilled for this to be considered default route
	}
	
	In case a train matches the ARS rules of multiple routes, precedence is as follows:
	1. train matches rules without priority in one or more routes -> first matching route is unconditionally set
	2. train matches rules with priority in one or more routes -> all of the matching routes are set (multi-ars)
			in the order given by priority, first available route is set
	3. route is default=true, default_prio=nil and train matches default_conj (if present) -> first default route is set
	4. one or more routes are default=true, with default_prio set,and train matches default_conj (if present)
			-> all of the matching routes are set (multi-ars) in the order given by priority, first available route is set
	
	For editing, those tables are transformed into lines in a text area:
	{ln=...} -> LN ...
	{rc=...} -> RC ...
	{c=...}  -> #...
	{default=true} -> *
	n -> ! (e.g. ln=..., n=true -> !LN ...)
	prio -> <num> (e.g. ln=..., prio=1 -> 1 LN ...)
	
	conj -> goes on the next line, with an & prepended, e.g.:
		{ln="S1", conj={rc="Left"}} ->
		LN S1
		& RC Left
	
	Example combining everything:
	ars = {
		[1] = {
			ln = "S1"
			n = true
			prio = 4
			conj = {
				rc = "R4"
			}
		}
		default = true
		default_prio = 2
		default_conj = {
			rc = "R5"
			n = true
		}
	} ->
	4 !LN S1
	& RC R4
	2 *
	& !RC R5
	
]]

local il = advtrains.interlocking


local function conj_to_text(conj, txt)
	while conj do
		n = ""
		if conj.n then
			n = "!"
		end
		if conj.ln then
			txt[#txt+1] = "& "..n.."LN "..conj.ln
		elseif conj.rc then
			txt[#txt+1] = "& "..n.."RC "..conj.rc
		end
		conj = conj.conj
	end
end

-- The ARS data are saved in a table format, but are entered in text format. Utility functions to transform between both.
function il.ars_to_text(arstab)
	if not arstab then
		return ""
	end
	
	local txt = {}

	for i, arsent in ipairs(arstab) do
		local prio = ""
		if arsent.prio then
			prio = arsent.prio.." "
		end
		local n = ""
		if arsent.n then
			n = "!"
		end
		if arsent.ln then
			txt[#txt+1] = prio..n.."LN "..arsent.ln
		elseif arsent.rc then
			txt[#txt+1] = prio..n.."RC "..arsent.rc
		elseif arsent.c then
			txt[#txt+1] = "#"..arsent.c
		end
		conj_to_text(arsent.conj, txt)
	end
	
	if arstab.default then
		local prio = ""
		if arstab.default_prio then
			prio = arstab.default_prio.." "
		end
		txt[#txt+1] = prio.."*"
		conj_to_text(arstab.default_conj, txt)
	end
	return table.concat(txt, "\n")
end

local function parse_ruleexp(line)
	local excl, key, val = string.match(line, "^%s*(!?)%s*([RL][CN])%s+(.+)%s*$")
	if key == "RC" then
		return {rc=val, n=(excl=="!")}
	elseif key == "LN" then
		return {ln=val, n=(excl=="!")}
	end
end

function il.text_to_ars(t)
	if not string.match(t, "%S+") then
		return nil
	end
	local arstab = {}
	local previtem
	for line in string.gmatch(t, "[^\r\n]+") do
		-- a) comment
		local ct = string.match(line, "^#(.*)$")
		if ct then
			arstab[#arstab+1] = {c = ct}
			previtem = nil
		else
			-- b) Conjunction to the previous item
			local conline = string.match(line, "^%s*&(.+)$")
			if conline then
				local conj = parse_ruleexp(conline)
				if conj and previtem==true then
					-- previtem was default
					arstab.default_conj = conj
					previtem = conj
				elseif conj and previtem then
					previtem.conj = conj
					previtem = conj
				else
					-- dont know what to do with line, put as comment
					arstab[#arstab+1] = {c = "? "..line}
					previtem = nil
				end
			else
				-- c) Normal rule spec
				local prio, ruleline = string.match(line, "^%s*([0-9]*)%s*(.+)%s*$")
				if ruleline == "*" then
					-- ruleline is the asterisk, this is default
					arstab.default = true
					arstab.default_prio = tonumber(prio) -- evals to nil if not given
					previtem = true -- marks that previtem was asterisk
				elseif ruleline then
					-- ruleline is present, parse it
					local rule = parse_ruleexp(ruleline)
					if not rule then
						-- dont know what to do with line, put as comment
						arstab[#arstab+1] = {c = "? "..line}
						previtem = nil
					else
						rule.prio = tonumber(prio) -- evals to nil if not given
						arstab[#arstab+1] = rule
						previtem = rule
					end
				else
					-- d) nothing else works, save line as comment
					arstab[#arstab+1] = {c = "? "..line}
					previtem = nil
				end
			end
		end
	end
	return arstab
end


local function match_arsent(arsent, train)
	local rule_matches = false
	if arsent.ln then
		local line = train.line
		rule_matches = line and arsent.ln == line
		if arsent.n then rule_matches = not rule_matches end
	elseif arsent.rc then
		local routingcode = train.routingcode
		rule_matches = routingcode and string.find(" "..routingcode.." ", " "..arsent.rc.." ", nil, true)
		if arsent.n then rule_matches = not rule_matches end
	end
	if rule_matches then
		-- if the entry has a conjunction, go on checking
		if arsent.conj then
			return match_arsent(arsent.conj, train)
		else
			return true
		end
	else
		return false
	end
end

-- Given an ARS rule table, check whether any of the clauses in it match the train.
-- Returns: match_specific, match_default
--		match_specific: One of the clauses explicitly matched (if this is non-false, match_default is not checked and always given false)
--		match_default: The default clause (*) matched (as well as any conjunctions attached to the default clause)
--		both of these can be either true (unconditional match), a number (priority for multi-ars) or false
function il.ars_check_rule_match(ars, train)
		if not ars then
			return nil, nil
		end
		for arskey, arsent in ipairs(ars) do
			local rule_matches = match_arsent(arsent, train)
			if rule_matches then
				return (arsent.prio or true), nil
			end
		end
		if ars.default then
			local def_matches = true
			if ars.default_conj then
				def_matches = match_arsent(ars.default_conj, train)
			end
			if def_matches then
				return false, (ars.default_prio or true)
			end
		end
		return false,false
end

local function sort_priority(sprio)
	-- TODO implement and return the correct sorted table
	-- for now just minimum
	local maxk,maxv = nil,10000
	for k,v in pairs(sprio) do
		if v<maxv then
			maxv = v
			maxk = k
		end
	end
	return maxk
end

local function find_rtematch(routes, train)
	local sprio = {}
	local default = nil
	local dprio = {}
	for rteid, route in ipairs(routes) do
		if route.ars then
			local mspec, mdefault = il.ars_check_rule_match(route.ars, train)
			--atdebug("route",rteid,"ars",route.ars,"gives", mspec, mdefault)
			if mspec == true then
				return rteid
			elseif mspec then
				sprio[rteid] = mspec
			end
			if mdefault == true then
				if not default then default = rteid end
			elseif mdefault then
				dprio[rteid] = mdefault
			end
		end
	end
	if next(sprio) then
		atdebug("Ars: SMultiArs", sprio, "is not implemented yet!")
		return sort_priority(sprio)
	elseif default then
		return default
	elseif next(dprio) then
		atdebug("Ars: DMultiArs", dprio, "is not implemented yet!")
		return sort_priority(dprio)
	else
		return nil
	end
end


function advtrains.interlocking.ars_check(signalpos, train, trig_from_dst)
	-- check for distant signal
	-- this whole check must be delayed until after the route setting has taken place, 
	-- because before that the distant signal is yet unknown
	if not trig_from_dst then
		minetest.after(0.5, function()
			-- does signal have dst?
			local _, remote = il.signal.get_aspect(signalpos)
			if remote then
				advtrains.interlocking.ars_check(remote, train, true)
			end
		end)
	end

	local sigd = il.db.get_sigd_for_signal(signalpos)
	local tcbs = sigd and il.db.get_tcbs(sigd)
	-- trigger ARS on this signal
	if tcbs and tcbs.routes then
		
		if tcbs.ars_disabled or tcbs.ars_ignore_next then
			-- No-ARS mode of signal.
			-- ignore...
			-- Note: ars_ignore_next is set by signalling formspec when route is cancelled
			tcbs.ars_ignore_next = nil
			return
		end
		if trig_from_dst and tcbs.no_dst_ars_trig then
			-- signal not to be triggered from distant
			return
		end
		
		if tcbs.routeset then
			-- ARS is not in effect when a route is already set
			-- just "punch" routesetting, just in case callback got lost.
			minetest.after(0, il.route.update_route, sigd, tcbs, nil, nil)
			return
		end
		
		local rteid = find_rtematch(tcbs.routes, train)
		if rteid then
			--atdebug("Ars setting ",rteid)
			--delay routesetting, it should not occur inside train step
			-- using after here is OK because that gets called on every path recalculation
			minetest.after(0, il.route.update_route, sigd, tcbs, rteid, nil)
		end
	end
end
