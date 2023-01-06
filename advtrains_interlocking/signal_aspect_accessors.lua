--- Signal aspect accessors
-- @module advtrains.interlocking

local A = advtrains.interlocking.aspects
local D = advtrains.distant
local I = advtrains.interlocking
local N = advtrains.ndb
local pts = advtrains.roundfloorpts

local signal_aspect_metatable = {
	__tostring = function(asp)
		local st = {}
		if asp.type2group and asp.type2name then
			table.insert(st, string.format("%q in group %q", asp.type2name, asp.type2group))
		end
		if asp.main then
			table.insert(st, string.format("current %d", asp.main))
		end
		if asp.main ~= 0 then
			if asp.dst then
				table.insert(st, string.format("next %d", asp.dst))
			end
			if asp.proceed_as_main then
				table.insert(st, "proceed as main")
			end
		end
		return string.format("[%s]", table.concat(st, ", "))
	end,
}

local get_aspect

local supposed_aspects = {}

--- Replace the signal aspect cache.
-- @function load_supposed_aspects
-- @param db The new database.
function I.load_supposed_aspects(tbl)
	if tbl then
		supposed_aspects = tbl
		for _, v in pairs(tbl) do
			setmetatable(v, signal_aspect_metatable)
		end
	end
end

--- Retrieve the signal aspect cache.
-- @function save_supposed_aspects
-- @return The current database in use.
function I.save_supposed_aspects()
	return supposed_aspects
end

--- Read the aspect of a signal strictly from cache.
-- @param pos The position of the signal.
-- @return[1] The aspect of the signal (if present in cache).
-- @return[2] The nil constant (otherwise).
local function get_supposed_aspect(pos)
	return supposed_aspects[pts(pos)]
end

--- Update the signal aspect information in cache.
-- @param pos The position of the signal.
-- @param asp The new signal aspect
local function set_supposed_aspect(pos, asp)
	supposed_aspects[pts(pos)] = asp
end

--- Get the definition of a node.
-- @param pos The position of the node.
-- @return[1] The definition of the node (if present).
-- @return[2] An empty table (otherwise).
local function get_ndef(pos)
	local node = N.get_node(pos)
	return minetest.registered_nodes[node.name] or {}
end

--- Get the aspects supported by a signal.
-- @function signal_get_supported_aspects
-- @param pos The position of the signal.
-- @return[1] The table of supported aspects (if present).
-- @return[2] The nil constant (otherwise).
local function get_supported_aspects(pos)
	local ndef = get_ndef(pos)
	if ndef.advtrains and ndef.advtrains.supported_aspects then
		return ndef.advtrains.supported_aspects
	end
	return nil
end

--- Adjust a new signal aspect to fit a signal.
-- @param pos The position of the signal.
-- @param asp The new signal aspect.
-- @return The adjusted signal aspect.
-- @return The information to pass to the `advtrains.set_aspect` field in the node definitions.
local function adjust_aspect(pos, asp)
	asp = table.copy(I.signal_convert_aspect_if_necessary(asp))
	setmetatable(asp, signal_aspect_metatable)

	local mainpos = D.get_main(pos)
	local nxtasp
	if mainpos then
		nxtasp = get_aspect(mainpos)
	end
	if asp.main ~= 0 and mainpos then
		asp.dst = nxtasp.main
	else
		asp.dst = nil
	end

	local suppasp = get_supported_aspects(pos)
	if not suppasp then
		return asp, asp
	end
	local stype = suppasp.type
	if stype == 2 then
		local group = suppasp.group
		local name
		if suppasp.dst_shift and nxtasp then
			asp.main = nil
			name = A.type1_to_type2main(nxtasp, group, suppasp.dst_shift)
		elseif asp.main ~= 0 and nxtasp and nxtasp.type2group == group and nxtasp.type2name then
			name = A.get_type2_dst(group, nxtasp.type2name)
		else
			name = A.type1_to_type2main(asp, group)
		end
		asp.type2group = group
		asp.type2name = name
		return asp, name
	end
	asp.type2name = nil
	asp.type2group = nil
	return asp, asp
end

--- Get the aspect of a signal without accessing the cache.
-- For most cases, `get_aspect` should be used instead.
-- @function signal_get_real_aspect
-- @param pos The position of the signal.
-- @return[1] The signal aspect adjusted using `adjust_aspect` (if present).
-- @return[2] The nil constant (otherwise).
local function get_real_aspect(pos)
	local ndef = get_ndef(pos)
	if ndef.advtrains and ndef.advtrains.get_aspect then
		local asp = ndef.advtrains.get_aspect(pos, node) or I.DANGER
		local suppasp = get_supported_aspects(pos)
		if suppasp and suppasp.type == 2 then
			asp = A.type2_to_type1(suppasp, asp)
		end
		return adjust_aspect(pos, asp)
	end
	return nil
end

--- Get the aspect of a signal.
-- @function signal_get_aspect
-- @param pos The position of the signal.
-- @return[1] The aspect of the signal (if present).
-- @return[2] The nil constant (otherwise).
get_aspect = function(pos)
	local asp = get_supposed_aspect(pos)
	if not asp then
		asp = get_real_aspect(pos)
		set_supposed_aspect(pos, asp)
	end
	return asp
end

--- Set the aspect of a signal.
-- @function signal_set_aspect
-- @param pos The position of the signal.
-- @param asp The new signal aspect.
-- @param[opt=false] skipdst Whether to skip updating distant signals.
local function set_aspect(pos, asp, skipdst)
	local node = N.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.set_aspect then
		local oldasp = I.signal_get_aspect(pos) or DANGER
		local newasp, aspval = adjust_aspect(pos, asp)
		set_supposed_aspect(pos, newasp)
		ndef.advtrains.set_aspect(pos, node, aspval)
		I.signal_on_aspect_changed(pos)
		local aspect_changed = A.not_equalp(oldasp, newasp)
		if (not skipdst) and aspect_changed then
			D.update_main(pos)
		end
	end
end

--- Remove a signal from cache.
-- @function signal_clear_aspect
-- @param pos The position of the signal.
local function clear_aspect(pos)
	set_supposed_aspect(pos, nil)
end

--- Readjust the aspect of a signal.
-- @function signal_readjust_aspect
-- @param pos The position of the signal.
local function readjust_aspect(pos)
	set_aspect(pos, get_aspect(pos))
end

I.signal_get_supported_aspects = get_supported_aspects
I.signal_get_real_aspect = get_real_aspect
I.signal_get_aspect = get_aspect
I.signal_set_aspect = set_aspect
I.signal_clear_aspect = clear_aspect
I.signal_readjust_aspect = readjust_aspect
