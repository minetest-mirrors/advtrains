local A = advtrains.interlocking.aspects
local D = advtrains.distant
local I = advtrains.interlocking
local N = advtrains.ndb
local pts = advtrains.roundfloorpts

local get_aspect

local supposed_aspects = {}

function I.load_supposed_aspects(tbl)
	if tbl then
		supposed_aspects = tbl
	end
end

function I.save_supposed_aspects()
	return supposed_aspects
end

local function get_supposed_aspect(pos)
	return supposed_aspects[pts(pos)]
end

local function set_supposed_aspect(pos, asp)
	supposed_aspects[pts(pos)] = asp
end

local function get_ndef(pos)
	local node = N.get_node(pos)
	return minetest.registered_nodes[node.name] or {}
end

local function get_supported_aspects(pos)
	local ndef = get_ndef(pos)
	if ndef.advtrains and ndef.advtrains.supported_aspects then
		return ndef.advtrains.supported_aspects
	end
	return nil
end

local function adjust_aspect(pos, asp)
	asp = table.copy(I.signal_convert_aspect_if_necessary(asp))

	local mainpos = D.get_main(pos)
	local nxtasp
	if asp.main ~= 0 and mainpos then
		nxtasp = get_aspect(mainpos)
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
		if asp.main ~= 0 and nxtasp and nxtasp.type2group == group and nxtasp.type2name then
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

local function get_real_aspect(pos)
	local ndef = get_ndef(pos)
	if ndef.advtrains and ndef.advtrains.get_aspect then
		local asp = ndef.advtrains.get_aspect(pos, node) or I.DANGER
		local suppasp = get_supported_aspects(pos)
		if suppasp.type == 2 then
			asp = A.type2main_to_type1(suppasp.group, asp)
		end
		return adjust_aspect(pos, asp)
	end
	return nil
end

get_aspect = function(pos)
	local asp = get_supposed_aspect(pos)
	if not asp then
		asp = get_real_aspect(pos)
		set_supposed_aspect(pos, asp)
	end
	return asp
end

local function set_aspect(pos, asp)
	local node = N.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if ndef and ndef.advtrains and ndef.advtrains.set_aspect then
		local oldasp = I.signal_get_aspect(pos) or DANGER
		local newasp, aspval = adjust_aspect(pos, asp)
		set_supposed_aspect(pos, newasp)
		ndef.advtrains.set_aspect(pos, node, aspval)
		I.signal_on_aspect_changed(pos)
		local aspect_changed = A.not_equalp(oldasp, newasp)
		if aspect_changed then
			D.update_main(pos)
		end
	end
end

local function clear_aspect(pos)
	set_supposed_aspect(pos, nil)
end

local function readjust_aspect(pos)
	set_aspect(pos, get_aspect(pos))
end

I.signal_get_supported_aspects = get_supported_aspects
I.signal_get_real_aspect = get_real_aspect
I.signal_get_aspect = get_aspect
I.signal_set_aspect = set_aspect
I.signal_clear_aspect = clear_aspect
I.signal_readjust_aspect = readjust_aspect
