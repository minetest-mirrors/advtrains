local aj_cache = {}
local aj_strout = {}

local aj_tostring, aj_execute

local rwt, sched

minetest.register_on_mods_loaded(function()
	if not advtrains.lines then return end
	rwt = advtrains.lines.rwt
	if not rwt then return end
	sched = advtrains.lines.sched
	if not sched then return end
	sched.register_callback("atcjit", function(d)
		local id, cmd = d.trainid, d.cmd
		if not (id and cmd) then return end
		local train = advtrains.trains[id]
		if not train then return end
		train.atc_arrow = d.arrow or false
		train.atc_command = cmd
		aj_execute(id, train)
	end)
end)

--[[ Notes on the pattern matching functions:
- Patterns can have multiple captures (e.g. coordinates). These captures
are passed starting from the second argument.
- The commands after the match are passed as the first argument. If the
command involves waiting, it should:
  - Set train.atc_command to the first argument passed to the function,
  - End with "do return end", and
  - Return true as the second argument
- The function should return a string to be compiled as the first result.
- In case of an error, the function should return nil as the first
argument and the error message as the second argument.
]]
local matchptn = {
	["A([01FT])"] = function(_, match)
		return string.format(
			"train.ars_disable=%s",
			(match=="0" or match=="F") and "true" or "false")
	end,
	["BB"] = function()
		return [[do
			train.atc_brake_target = -1
			train.tarvelocity = 0
		end]]
	end,
	["B([0-9]+)"] = function(_, match)
		return string.format([[do
			train.atc_brake_target = %s
			if not train.tarvelocity or train.tarvelocity > train.atc_brake_target then
				train.tarvelocity = train.atc_brake_target
			end
		end]], match)
	end,
	["D([0-9]+)"] = function(cont, match)
		return string.format([[do
			train.atc_delay = %s
			train.atc_command = %q
			return
		end]], match, cont), true
	end,
	["Ds([0-9]+)%+([0-9]+)"] = function(cont, int, off)
		if sched then
			return string.format([[do
				local rwt = advtrains.lines.rwt
				local tnext = rwt.next_rpt(rwt.now(),%s,%s)
				local edata = {trainid = train.id, cmd = %q, arrow = train.atc_arrow}
				advtrains.lines.sched.enqueue(tnext,"atcjit",edata,"atcjit-"..(train.id),1)
			end]], int, off, cont), true
		else
			return string.format([[do
				train.atc_delay = %s-(os.time()-%s)%%%s
				train.atc_command = %q
				return
			end]], int, off, int, cont), true
		end
	end,
	["Ds%+([0-9]+)"] = function(cont, delta)
		if sched then
			return string.format([[do
				local edata = {trainid = train.id, cmd = %q, arrow = train.atc_arrow}
				advtrains.lines.sched.enqueue_in(%s,"atcjit",edata,"atcjit-"..(train.id),1)
			end]], cont, delta), true
		else
			return string.format([[do
				train.atc_delay = %s
				train.atc_command = %q
				return
			end]], delta, cont), true
		end
	end,
	["(%bI;)"] = function(cont, match)
		local i = 2
		local l = #match
		local epos
		while (i<l) do
			local b, e, c = string.find(match,"([IE])",i)
			if c == "I" then
				b, e = string.find(match,"%bI;", b)
				-- This is unlikely to happen since the %b pattern is balanced
				if not (b and e) then return nil, "Malformed nested I statement" end
				i = e+1
			else
				epos = b
				break
			end
		end
		local endp = string.find(match,"[WDI]") and true
		local cond = string.match(match,"^I([+-])")
		if cond then
			local vtrue = string.sub(match, 3, epos and epos-1 or -2)
			local vfalse = epos and string.sub(match, epos+1, -2)
			local cstr = (cond == "-") and "not" or ""
			local tstr, err = aj_tostring(vtrue, 1, cont)
			if not tstr then return nil, err end
			if vfalse then
				local fstr, err = aj_tostring(vfalse, 1, cont)
				if not fstr then return nil, err end
				return string.format("if %s train.atc_arrow then %s else %s end",
					cstr, tstr, fstr)
			else
				return string.format("if %s train.atc_arrow then %s end", cstr, tstr)
			end
		else
			local op, ref = string.match(match,"^I([<>]=?)([0-9]+)")
			if not op then
				return nil, "Invalid I statement"
			end
			local spos = 2+#op+#ref
			local vtrue = string.sub(match, spos, epos and epos-1 or -2)
			local vfalse = epos and string.sub(match, epos+1, -2)
			local cstr = string.format("train.velocity %s %s", op, ref)
			local tstr = aj_tostring(vtrue, 1, cont)
			if vfalse then
				local fstr, err = aj_tostring(vfalse, 1, cont)
				if not fstr then return nil, err end
				return string.format("if %s then %s else %s end", cstr, tstr, fstr)
			else
				return string.format("if %s then %s end", cstr, tstr)
			end
		end
	end,
	["K"] = function()
		return [=[do
			if train.door_open == 0 then
				atwarn(sid(id),attrans("ATC Kick command warning: Doors are closed"))
			elseif train.velocity>0 then
				atwarn(sid(id),attrans("ATC Kick command warning: Train moving"))
			else
				local tp = train.trainparts
				for i = 1, #tp do
					local data = advtrains.wagons[tp[i]]
					local obj = advtrains.wagon_objects[tp[i]]
					if data and obj then
						local ent = obj:get_luaentity()
						if ent then
							for seatno, seat in pairs(ent.seats) do
								if data.seatp[seatno] and not ent:is_driver_stand(seat) then
									ent:get_off(seatno)
								end
							end
						end
					end
				end
			end
		end]=]
	end,
	["O([LR])"] = function(_, match)
		local tt = {L = -1, R = 1}
		return string.format("train.door_open = %d*(train.atc_arrow and 1 or -1)",tt[match])
	end,
	["OC"] = function()
		return "train.door_open = 0"
	end,
	["R"] = function()
		return [[
			if train.velocity<=0 then
				advtrains.invert_train(id)
				advtrains.train_ensure_init(id, train)
			else
				atwarn(sid(id),attrans("ATC Reverse command warning: didn't reverse train, train moving!"))
			end]]
	end,
	["SM"] = function()
		return "train.tarvelocity=train.max_speed"
	end,
	["S([0-9]+)"] = function(_, match)
		return string.format("train.tarvelocity=%s",match)
	end,
	["W"] = function(cont)
		return string.format([[do
			train.atc_wait_finish=true
			train.atc_command=%q
			return
		end]], cont), true
	end,
}

local function aj_tostring_single(cmd, pos, cont)
	if not pos then pos = 1 end
	for pattern, func in pairs(matchptn) do
		local match = {string.find(cmd, "^"..pattern, pos)}
		if match[1] then
			local e = match[2]
			match[2] = string.sub(cmd, e+1)..(cont or "")
			return e+1, func(unpack(match, 2))
		end
	end
	return nil
end

aj_tostring = function(cmd, pos, cont)
	if not pos then pos = 1 end
	local t = {}
	local endp = false
	while pos <= #cmd do
		if string.match(cmd,"^%s+$", pos) then break end
		local _, e = string.find(cmd, "^%s+", pos)
		if e then pos = e+1 end
		local nxt, str
		nxt, str, endp = aj_tostring_single(cmd, pos, cont or "")
		if not str then
			return nil, (endp or "Invalid command or malformed I statement: "..string.sub(cmd,pos))
		end
		t[#t+1] = str
		pos = nxt
		if endp then
			break
		end
	end
	return table.concat(t,"\n"), pos
end

local function aj_compile(cmd)
	local c = aj_cache[cmd]
	if c then
		if type(c) == "function" then
			return c, aj_strout[cmd]
		else
			return nil, c
		end
	else
		local str, err = aj_tostring(cmd)
		if not str then
			aj_cache[cmd] = err
			return nil, err
		end
		str = string.format([[return function(id, train)
			%s
			train.atc_command=nil
		end]], str)
		local f, e = loadstring(str)
		if not f then
			aj_cache[cmd] = e
			return nil, e
		end
		f = f()
		aj_cache[cmd] = f
		aj_strout[cmd] = str
		return f, str
	end
end

aj_execute = function(id,train)
	if not train.atc_command then return end
	local func, err = aj_compile(train.atc_command)
	if func then return func(id,train) end
	return nil, err
end

return {
	compile = aj_compile,
	execute = aj_execute
}
