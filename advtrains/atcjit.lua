local aj_cache = {}
local aj_strout = {}

local aj_tostring

local matchptn = {
	["A[01FT]"] = function(match)
		return string.format(
			"advtrains.interlocking.set_ars_disable(train,%s)",
			(match=="0" or match=="F") and "true" or "false"), false
	end,
	["BB"] = function()
		return [[do
			train.atc_brake_target = -1
			train.tarvelocity = 0
		end]], 2
	end,
	["B([0-9]+)"] = function(match)
		return string.format([[do
			train.atc_brake_target = %s
			if not train.tarvelocity or train.tarvelocity > train.atc_brake_target then
				train.tarvelocity = train.atc_brake_target
			end
		end]], match),#match+1
	end,
	["D([0-9]+)"] = function(match)
		return string.format("train.atc_delay = %s", match), #match+1, true
	end,
	["(%bI;)"] = function(match)
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
			local tstr, err = aj_tostring(vtrue, 1, true)
			if not tstr then return nil, err end
			if vfalse then
				local fstr, err = aj_tostring(vfalse, 1, true)
				if not fstr then return nil, err end
				return string.format("if %s train.atc_arrow then %s else %s end",
					cstr, tstr, fstr), l, endp
			else
				return string.format("if %s train.atc_arrow then %s end", cstr, tstr), l, endp
			end
		else
			local op, ref = string.match(match,"^I([<>]=?)([0-9]+)")
			if not op then
				return _, "Invalid I statement"
			end
			local spos = 2+#op+#ref
			local vtrue = string.sub(match, spos, epos and epos-1 or -2)
			local vfalse = epos and string.sub(match, epos+1, -2)
			local cstr = string.format("train.velocity %s %s", op, ref)
			local tstr = aj_tostring(vtrue, 1, true)
			if vfalse then
				local fstr, err = aj_tostring(vfalse, 1, true)
				if not fstr then return nil, err end
				return string.format("if %s then %s else %s end", cstr, tstr, fstr), l, endp
			else
				return string.format("if %s then %s end", cstr, tstr), l, endp
			end
		end
	end,
	["K"] = function()
		return [=[do
			if train.door_open == 0 then
				_w[#_w+1] = attrans("ATC Kick command warning: Doors are closed")
			elseif train.velocity>0 then
				_w[#_w+1] = attrans("ATC Kick command warning: Train moving")
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
		end]=], 1
	end,
	["O([LR])"] = function(match)
		local tt = {L = -1, R = 1}
		return string.format("train.door_open = %d*(train.atc_arrow and 1 or -1)",tt[match]), 2
	end,
	["OC"] = function(match)
		return "train.door_open = 0", 2
	end,
	["R"] = function()
		return [[
			if train.velocity<=0 then
				advtrains.invert_train(id)
				advtrains.train_ensure_init(id, train)
			else
				_w[#_w+1] = attrans("ATC Reverse command warning: didn't reverse train, train moving!")
			end]], 1
	end,
	["SM"] = function()
		return "train.tarvelocity=train.max_speed", 2
	end,
	["S([0-9]+)"] = function(match)
		return string.format("train.tarvelocity=%s",match), #match+1
	end,
	["W"] = function()
		return "train.atc_wait_finish=true", 1, true
	end,
}

local function aj_tostring_single(cmd, pos)
	if not pos then pos = 1 end
	for pattern, func in pairs(matchptn) do
		local match = {string.match(cmd, "^"..pattern, pos)}
		if match[1] then
			return func(unpack(match))
		end
	end
	return nil
end

aj_tostring = function(cmd, pos, noreset)
	if not pos then pos = 1 end
	local t = {}
	local endp = false
	while pos <= #cmd do
		if string.match(cmd,"^%s+$", pos) then break end
		local _, e = string.find(cmd, "^%s+", pos)
		if e then pos = e+1 end
		local str, len
		str, len, endp = aj_tostring_single(cmd, pos)
		if not str then
			return nil, (len or "Invalid command or malformed I statement: "..string.sub(cmd,pos))
		end
		t[#t+1] = str
		pos = pos+len
		if endp then
			local cont = string.sub(cmd, pos)
			if not string.match(cont, "^%s*$") then
				t[#t+1] = string.format("_c[#_c+1]=%q",cont)
			end
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
			local _c={}
			local _w={}
			%s
			if _c[1] then train.atc_command=table.concat(_c)
			else train.atc_command=nil end
			return _w, nil
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

local function aj_execute(id,train)
	if not train.atc_command then return end
	local func, err = aj_compile(train.atc_command)
	if func then return func(id,train) end
	return nil, err
end

return {
	compile = aj_compile,
	execute = aj_execute
}
