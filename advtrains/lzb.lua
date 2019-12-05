-- lzb.lua
-- Enforced and/or automatic train override control, providing the on_train_approach callback

--[[
Documentation of train.lzb table
train.lzb = {
	trav = Current index that the traverser has advanced so far
	oncoming = table containing oncoming signals, in order of appearance on the path
		{
			pos = position of the point
			idx = where this is on the path
			spd = speed allowed to pass
			fun = function(pos, id, train, index, speed, lzbdata)
			-- Function that determines what to do on the train in the moment it drives over that point.
		}
}
each step, for every item in "oncoming", we need to determine the location to start braking (+ some safety margin)
and, if we passed this point for at least one of the items, initiate brake.
When speed has dropped below, say 3, decrease the margin to zero, so that trains actually stop at the signal IP.
The spd variable and travsht need to be updated on every aspect change. it's probably best to reset everything when any aspect changes
]]


local params = {
	BRAKE_SPACE = 10,
	AWARE_ZONE  = 50,

	ADD_STAND  =  2.5,
	ADD_SLOW   =  1.5,
	ADD_FAST   =  7,
	ZONE_ROLL  =  2,
	ZONE_HOLD  =  5, -- added on top of ZONE_ROLL
	ZONE_VSLOW =  3, -- When speed is <2, still allow accelerating

	DST_FACTOR =  1.5,

	SHUNT_SPEED_MAX = advtrains.SHUNT_SPEED_MAX,
}

function advtrains.set_lzb_param(par, val)
	if params[par] and tonumber(val) then
		params[par] = tonumber(val)
	else
		error("Inexistant param or not a number")
	end
end


local function look_ahead(id, train)

	local acc = advtrains.get_acceleration(train, 1)
	local vel = train.velocity
	local brakedst = ( -(vel*vel) / (2*acc) ) * params.DST_FACTOR

	local brake_i = advtrains.path_get_index_by_offset(train, train.index, brakedst + params.BRAKE_SPACE)
	--local aware_i = advtrains.path_get_index_by_offset(train, brake_i, AWARE_ZONE)

	local lzb = train.lzb
	local trav = lzb.trav

	--train.debug = lspd

	while trav <= brake_i do
		trav = trav + 1
		local pos = advtrains.path_get(train, trav)
		-- check offtrack
		if trav > train.path_trk_f then
			table.insert(lzb.oncoming, {
				pos = pos,
				idx = trav-1,
				spd = 0,
			})
		else
			-- run callbacks
			-- Note: those callbacks are defined in trainlogic.lua for consistency with the other node callbacks
			advtrains.tnc_call_approach_callback(pos, id, train, trav, lzb.data)

		end
	end

	lzb.trav = trav

end

--[[
The .i element is the index at which LZB overrides the train control with the
lever specified by the index value. The .v element is the speed at which the
train control is taken over by LZB with the lever specified by the index. The .t
element calculates the time needed for the train to reach the point where the
control is taken over by LZB with the lever specified by the index. Unintialized
.v and .t values indicate that the train has passed the point with the
corresponding index. Note that thhe 0th item contains the data related to the
LZB point itself, and not related to the emergency brake.
]]
function advtrains.lzb_map_entry(train, lzb)
	local ret = {[0]={},[1]={},[2]={},[3]={}}
	if (not train) or (not lzb) then return ret end
	local ti = train.index
	local v0 = train.velocity
	local v1 = lzb.spd
	local a = advtrains.get_acceleration(train, train.lever)
	local s = (v1*v1-v0*v0)/2/advtrains.get_acceleration(train, 1)
	if v0 > 3 then s = s + params.ADD_FAST
	elseif v0 <=0 then s = s + params.ADD_STAND
	else s = s + params.ADD_SLOW
	end
	ret[0].i = lzb.idx
	ret[1].i = advtrains.path_get_index_by_offset(train, ret[0].i, -s)
	ret[2].i = advtrains.path_get_index_by_offset(train, ret[1].i, -params.ZONE_ROLL)
	ret[3].i = advtrains.path_get_index_by_offset(train, ret[2].i, -params.ZONE_HOLD)
	if a == 0 then ret[3].t = (ret[3].i)/v0
	else
		ret[3].t = advtrains.solve_quadratic_equation(a/2, v0, (ti-ret[3].i))
		if not ret[3].t then ret[3].t = 0
		else
			if ret[3].t[1]<0 then
				if ret[3].t[2]<0 then ret[3].t = ret[3].t[2]
				else ret[3].t = math.abs(math.max(ret[3].t[1], ret[3].t[2]))
				end
			else
				if ret[3].t[2]<0 then ret[3].t = ret[3].t[1]
				else ret[3].t = math.min(ret[3].t[1], ret[3].t[2])
				end
			end
		end
	end
	ret[3].v = (v0 + a*ret[3].t)
	if ret[3].v <= lzb.spd then ret[3].v = lzb.spd end -- Avoid devision by zero
	if ret[3].v > (train.max_speed or 10) then ret[3].v = train.max_speed or 0 end
	ret[2].v = ret[3].v
	ret[2].t = (ret[3].i-ret[2].i)/ret[3].v
	ret[1].t = advtrains.solve_quadratic_equation(advtrains.get_acceleration(train,2),ret[2].v,(ret[2].i-ret[1].i))
	if not ret[1].t then ret[1].t = 0
	else
		if ret[1].t[1]<0 then
			if ret[1].t[2]<0 then ret[1].t = ret[1].t[2]
			else ret[1].t = math.abs(math.max(ret[1].t[1], ret[1].t[2]))
			end
		else
			if ret[1].t[2]<0 then ret[1].t = ret[1].t[1]
			else ret[1].t = math.min(math.max(ret[1].t[1], ret[1].t[2]))
			end
		end
	end
	ret[1].v = (ret[2].v + advtrains.get_acceleration(train,2)*ret[1].t)
	if ret[1].v <= lzb.spd then ret[1].v = lzb.spd end
	ret[0].v = lzb.spd
	ret[0].t = (ret[0].v-ret[1].v)/advtrains.get_acceleration(train,1)
	return ret
end

--[[
advtrains.lzb_get_limit_by_entry - get the limit
Returns a table contraining the speed and the acceleration limits
]]
function advtrains.lzb_get_limit_by_entry(train, lzb)
	local ret = {}
	local lzbmap = advtrains.lzb_map_entry(train, lzb)
	if not (lzbmap[3].i and lzbmap[2].i and lzbmap[1].i and lzbmap[0].i) then
		return {}
	elseif (lzbmap[3].i > train.index) then return {}
	elseif (lzbmap[2].i > train.index) then ret.lever = 3
	elseif (lzbmap[1].i > train.index) then ret.lever = 2
	else ret.lever = 1
	end
	if ret.lever == 3 then ret.velocity = lzbmap[3].v
	else
		local s = train.index - lzbmap[ret.lever].i
		local a = advtrains.get_acceleration(train, ret.lever)
		local v0 = lzbmap[ret.lever].v
		ret.velocity = math.sqrt(2*a*s - v0*v0)
	end
	if ret.velocity < train.velocity -1 then ret.lever = ret.lever - 1 end
	return ret
end

-- Get next LZB restriction with the lowest speed restriction
function advtrains.lzb_get_next(train)
	if lever == 4 then return nil end
	local lzb = train.lzb
	local i = 1
	local ret
	local a = advtrains.get_acceleration(train, 3) -- Acceleration
	local v0 = train.velocity
	-- Remove LZB entries that are no longer valid
	while i <= #lzb.oncoming do
		if lzb.oncoming[i].idx < train.index then
			local ent = lzb.oncoming[i]
			if ent.fun then
				ent.fun(ent.pos, id, train, ent.idx, ent.spd, lzb.data)
			end
			table.remove(lzb.oncoming, i)
		else
			i = i + 1
		end
	end
	-- Now run through all the LZB entries and find the one with the lowest
	-- speed requirement
	for _, it in ipairs(lzb.oncoming) do
		local v1 = it.spd
		if v1 and v1 <= v0 then
			local curlimit = advtrains.lzb_get_limit_by_entry(train, it)
			local retlimit = advtrains.lzb_get_limit_by_entry(train, ret)
			if not ret then ret = it
			elseif not curlimit.velocity then
			elseif retlimit.velocity > curlimit.velocity then
				ret = it
			end
		end
	end
	return ret
end

local function invalidate(train)
	train.lzb = {
		trav = atfloor(train.index),
		data = {},
		oncoming = {},
	}
end

function advtrains.lzb_invalidate(train)
	invalidate(train)
end

-- Add LZB control point
-- udata: User-defined additional data
function advtrains.lzb_add_checkpoint(train, index, speed, callback, udata)
	local lzb = train.lzb
	local pos = advtrains.path_get(train, index)
	table.insert(lzb.oncoming, {
		pos = pos,
		idx = index,
		spd = speed,
		fun = callback,
		udata = udata,
	})
end


advtrains.te_register_on_new_path(function(id, train)
	invalidate(train)
	look_ahead(id, train)
end)

advtrains.te_register_on_update(function(id, train)
	if not train.path or not train.lzb then
		atprint("LZB run: no path on train, skip step")
		return
	end
	look_ahead(id, train)
end, true)
