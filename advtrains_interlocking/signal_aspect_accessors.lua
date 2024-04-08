--- Signal aspect accessors
-- @module advtrains.interlocking

local A = advtrains.interlocking.aspect
local D = advtrains.distant
local I = advtrains.interlocking
local N = advtrains.ndb
local pts = advtrains.roundfloorpts

local get_aspect

local supposed_aspects = {}

--- Replace the signal aspect cache.
-- @function load_supposed_aspects
-- @param db The new database.
function I.load_supposed_aspects(tbl)
	if tbl then
		supposed_aspects = {}
		for k, v in pairs(tbl) do
			supposed_aspects[k] = A(v)
		end
	end
end

--- Retrieve the signal aspect cache.
-- @function save_supposed_aspects
-- @return The current database in use.
function I.save_supposed_aspects()
	local t = {}
	for k, v in pairs(supposed_aspects) do
		t[k] = v:plain(true)
	end
	return t
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
	return (minetest.registered_nodes[node.name] or {}), node
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
	local asp = A(asp)

	local mainpos = D.get_main(pos)
	local nxtasp
	if mainpos then
		nxtasp = get_aspect(mainpos)
	end
	local suppasp = get_supported_aspects(pos)
	if not suppasp then
		return asp
	end
	return asp:adjust_distant(nxtasp, suppasp.dst_shift):to_group(suppasp.group)
end

--- Get the aspect of a signal without accessing the cache.
-- For most cases, `get_aspect` should be used instead.
-- @function signal_get_real_aspect
-- @param pos The position of the signal.
-- @return[1] The signal aspect adjusted using `adjust_aspect` (if present).
-- @return[2] The nil constant (otherwise).
local function get_real_aspect(pos)
	local ndef, node = get_ndef(pos)
	if ndef.advtrains and ndef.advtrains.get_aspect then
		local asp = ndef.advtrains.get_aspect(pos, node) or I.DANGER
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
		local newasp = adjust_aspect(pos, asp)
		set_supposed_aspect(pos, newasp)
		ndef.advtrains.set_aspect(pos, node, newasp)
		I.signal_on_aspect_changed(pos)
		local aspect_changed = oldasp ~= newasp
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
