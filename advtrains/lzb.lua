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

--[[ Distance needed to accelerate for t (time) starting from v0 with acc. a:
             at²
s = v0 * t + ---
              2
]]
function advtrains.lzb_get_limit_zone(train, lzb, lever, vel)
	local lvr = lever or train.lever
	local v0 = vel or train.velocity
	local v1 = lzb.spd
	local s = (v1*v1-v0*v0)/2/advtrains.get_acceleration(train, 1)
	if v0 > 3 then s = s + params.ADD_FAST
	elseif v0 <= 0 then s = s + params.ADD_STAND
	else s = s + params.ADD_SLOW
	end
	if v0 >= params.ZONE_VSLOW then
	  if lvr >= 2 then s = s + params.ZONE_HOLD end
	  if lvr >= 3 then s = s + params.ZONE_ROLL end
	end
	return advtrains.path_get_index_by_offset(train, lzb.idx, -s)
end

function advtrains.lzb_get_limit_by_entry(train, lzb, dtime)
	if not (type(lzb)=="table") then return nil end
	local getacc = advtrains.get_acceleration
	local v0 = train.velocity
	local v1 = lzb.spd
	local t = dtime or 0.2
	local i = advtrains.lzb_get_limit_zone(train, lzb, 4, v0 + getacc(train,4))
	if train.index + v0*t + getacc(train,4)*t*t/2  <= i then return 4 end
	i = advtrains.lzb_get_limit_zone(train, lzb, 3, v0)
	if train.index + v0*t <= i then return 3 end
	i = advtrains.path_get_index_by_offset(train, i, params.ZONE_HOLD)
	if train.index + v0*t + getacc(train,2)*t*t/2 <= i then return 2 end
	i = advtrains.path_get_index_by_offset(train, i, params.ZONE_ROLL)
	if train.index + v0*t + getacc(train,1)*t*t/2 <= i then return 1 end
	return 0
end

-- Get next LZB restriction with the lowest speed restriction
-- The return values include the LZB entry and the speed limit
function advtrains.lzb_get_next(train,dtime)
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
			if not ret then ret = it
			else
				local retlimit = advtrains.lzb_get_limit_by_entry(train,ret,dtime)
				local curlimit = advtrains.lzb_get_limit_by_entry(train,ret,dtime)
				if retlimit and retlimit > curlimit then ret=it
				elseif retlimit == curlimit and it.idx < ret.idx then ret=it
				end
			end
		end
	end
	return ret,advtrains.lzb_get_limit_by_entry(train, ret,dtime)
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
