--- Distant signaling.
-- This module implements a database backend for distant signal assignments.
-- The actual modifications to signal aspects are still done by signal aspect accessors.
-- @module advtrains.interlocking.distant

local db_distant = {}
local db_distant_of = {}

local A = advtrains.interlocking.aspects
local pts = advtrains.encode_pos
local stp = advtrains.decode_pos

--- Replace the distant signal assignment database.
-- @function load
-- @param db The new database to load.
local function db_load(x)
	if type(x) ~= "table" then
		return
	end
	db_distant = x.distant
	db_distant_of = x.distant_of
end

--- Retrieve the current distant signal assignment database.
-- @function save
-- @return The current database.
local function db_save()
	return {
		distant = db_distant,
		distant_of = db_distant_of,
	}
end

local update_signal, update_main, update_dst

--- Unassign a distant signal.
-- @function unassign_dst
-- @param dst The position of the distant signal.
-- @param[opt=false] force Whether to skip callbacks.
local function unassign_dst(dst, force)
	local pts_dst = pts(dst)
	local main = db_distant_of[pts_dst]
	db_distant_of[pts_dst] = nil
	if main then
		local pts_main = main[1]
		local t = db_distant[pts_main]
		if t then
			t[pts_dst] = nil
		end
	end
	if not force then
		update_dst(dst)
	end
end

--- Unassign a main signal.
-- @function unassign_main
-- @param main The position of the main signal.
-- @param[opt=false] force Whether to skip callbacks.
local function unassign_main(main, force)
	local pts_main = pts(main)
	local t = db_distant[pts_main]
	if not t then
		return
	end
	for pts_dst in pairs(t) do
		local realmain = db_distant_of[pts_dst]
		if realmain and realmain[1] == pts_main then
			db_distant_of[pts_dst] = nil
			if not force then
				local dst = stp(pts_dst)
				update_dst(dst)
			end
		end
	end
	db_distant[pts_main] = nil
end

--- Remove all (main and distant) signal assignments from a signal.
-- @function unassign_all
-- @param pos The position of the signal.
-- @param[opt=false] force Whether to skip callbacks.
local function unassign_all(pos, force)
	unassign_main(pos)
	unassign_dst(pos, force)
end

--- Check whether a signal is "appropriate" for the distant signal system.
-- Currently, a signal is considered appropriate if its signal aspect can be set.
-- @function appropriate_signal
-- @param pos The position of the signal
local function appropriate_signal(pos)
	local node = advtrains.ndb.get_node(pos)
	local ndef = minetest.registered_nodes[node.name] or {}
	if not ndef then
		return false
	end
	local atdef = ndef.advtrains
	if not atdef then
		return false
	end
	return atdef.supported_aspects and atdef.set_aspect and true
end

--- Assign a distant signal to a main signal.
-- @function assign
-- @param main The position of the main signal.
-- @param dst The position of the distant signal.
-- @param[opt="manual"] by The method of assignment.
-- @param[opt=false] skip_update Whether to skip callbacks.
local function assign(main, dst, by, skip_update)
	if not (appropriate_signal(main) and appropriate_signal(dst)) then
		return
	end
	local pts_main = pts(main)
	local pts_dst = pts(dst)
	local t = db_distant[pts_main]
	if not t then
		t = {}
		db_distant[pts_main] = t
	end
	if not by then
		by = "manual"
	end
	unassign_dst(dst, true)
	t[pts_dst] = by
	db_distant_of[pts_dst] = {pts_main, by}
	if not skip_update then
		update_dst(dst)
	end
end

--- Get the distant signals assigned to a main signal.
-- @function get_distant
-- @param main The position of the main signal.
-- @treturn {[pos]=by,...} A table of distant signals, with the positions encoded using `advtrains.encode_pos`.
local function get_distant(main)
	local pts_main = pts(main)
	return db_distant[pts_main] or {}
end

--- Get the main signal assigned the a distant signal.
-- @function get_main
-- @param dst The position of the distant signal.
-- @return The position of the main signal.
-- @return The method of assignment.
local function get_main(dst)
	local pts_dst = pts(dst)
	local main = db_distant_of[pts_dst]
	if not main then
		return
	end
	if main[1] then
		return stp(main[1]), unpack(main, 2)
	else
		return unpack(main)
	end
end

--- Update all distant signals assigned to a main signal.
-- @function update_main
-- @param main The position of the main signal.
update_main = function(main)
	local pts_main = pts(main)
	local t = get_distant(main)
	for pts_dst in pairs(t) do
		local dst = stp(pts_dst)
		advtrains.interlocking.signal_readjust_aspect(dst)
	end
end

--- Update the aspect of a distant signal.
-- @function update_dst
-- @param dst The position of the distant signal.
update_dst = function(dst)
	advtrains.interlocking.signal_readjust_aspect(dst)
end

--- Update the aspect of a combined (main and distant) signal and all distant signals assigned to it.
-- @function update_signal
-- @param pos The position of the signal.
update_signal = function(pos)
	update_main(pos)
	update_dst(pos)
end

advtrains.distant = {
	load = db_load,
	save = db_save,
	assign = assign,
	unassign_dst = unassign_dst,
	unassign_main = unassign_main,
	unassign_all = unassign_all,
	get_distant = get_distant,
	get_dst = get_distant,
	get_main = get_main,
	update_main = update_main,
	update_dst = update_dst,
	update_signal = update_signal,
	appropriate_signal = appropriate_signal,
}
