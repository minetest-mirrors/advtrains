--- Auxiliary functions for the reworked speed restriction system.
-- For this library, the speed limit may be represented using
--
-- * A non-negative number representing a speed limit in m/s
-- * `-1` or `nil`, which lifts the speed limit
--
-- The use of other values (in particular, `nan` and `inf`) may result in undefined behavior.
--
-- Please note the difference between the meaning of `nil` in this library and in signal aspect tables.

--- Check if `a` is more strict than `b`
-- @function lessp
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_lessp(a, b)
	if not a or a == -1 then
		return false
	elseif not b or b == -1 then
		return true
	else
		return a < b
	end
end

--- Check if `a` is less strict than `b`
-- @function greaterp
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_greaterp(a, b)
	return s_lessp(b, a)
end

--- Check if `a` is not more strict than `b`
-- @function not_lessp
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_not_lessp(a, b)
	return not s_lessp(a, b)
end

--- Check if `a` is not less strict than `b`
-- @function not_greaterp
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_not_greaterp(a, b)
	return not s_greaterp(a, b)
end

--- Check if `a` and `b` represent equivalent speed limits
-- @function equalp
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_equalp(a, b)
	return (a or -1) == (b or -1)
end

--- Check if `a` and `b` do not represent equivalent speed limits
-- @function not_equalp
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_not_equalp(a, b)
	return (a or -1) ~= (b or -1)
end

--- Returns the speed limit that is less strict
-- @function max
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_max(a, b)
	if s_lessp(a, b) then
		return b
	else
		return a
	end
end

--- Returns the speed limit that is more strict
-- @function min
-- @param a an object representing a speed limit
-- @param b an object representing a speed limit
local function s_min(a, b)
	if s_lessp(a, b) then
		return a
	else
		return b
	end
end

--- Returns the strictest speed limit in a table
-- @param tbl a table of speed limits
local function get_speed_restriction_from_table (tbl)
	local strictest = -1
	for _, v in pairs(tbl) do
		strictest = s_min(strictest, v)
	end
	if strictest == -1 then
		return nil
	end
	return strictest
end

--- Update a value in the speed limit table
-- @param tbl the `speed_restriction` field of a train table
-- @param rtype the type of speed limit
-- @param rval the speed limit of the given type
local function set_speed_restriction (tbl, rtype, rval)
	if rval then
		tbl[rtype or "main"] = rval
	end
	return tbl
end

--- Set the speed limit of a train
-- @function set_restriction
-- @param train the train object
-- @param rtype the type of speed limit
-- @param rval the speed limit of the given type
local function set_speed_restriction_for_train (train, rtype, rval)
	local t = train.speed_restrictions_t or {main = train.speed_restriction}
	train.speed_restrictions_t = set_speed_restriction(t, rtype, rval)
	train.speed_restriction = get_speed_restriction_from_table(t)
end

--- Set the speed limit of a train based on a signal aspect
-- @function merge_aspect
-- @param train the train object
-- @param asp the signal aspect table
local function merge_speed_restriction_from_aspect_to_train (train, asp)
	return set_speed_restriction_for_train(train, asp.type, asp.main)
end

return {
	lessp = s_lessp,
	greaterp = s_greaterp,
	not_lessp = s_not_lessp,
	not_greaterp = s_not_greaterp,
	equalp = s_equalp,
	not_equalp = s_not_equalp,
	max = s_max,
	min = s_min,
	set_restriction = set_speed_restriction_for_train,
	merge_aspect = merge_speed_restriction_from_aspect_to_train,
}
