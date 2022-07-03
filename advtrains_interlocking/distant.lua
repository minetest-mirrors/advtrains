local db_distant = {}
local db_distant_of = {}

local A = advtrains.interlocking.aspects
local pts = advtrains.encode_pos
local stp = advtrains.decode_pos

local function db_load(x)
	if type(x) ~= "table" then
		return
	end
	db_distant = x.distant
	db_distant_of = x.distant_of
end

local function db_save()
	return {
		distant = db_distant,
		distant_of = db_distant_of,
	}
end

local update_signal, update_main, update_dst

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

local function unassign_all(pos, force)
	unassign_main(pos)
	unassign_dst(pos, force)
end

local function assign(main, dst, by, skip_update)
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

local function pre_occupy(dst, by)
	local pts_dst = pts(dst)
	unassign_dst(dst)
	db_distant_of[pts_dst] = {nil, by}
end

local function get_distant(main)
	local pts_main = pts(main)
	return db_distant[pts_main] or {}
end

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

update_main = function(main)
	local pts_main = pts(main)
	local t = get_distant(main)
	for pts_dst in pairs(t) do
		local dst = stp(pts_dst)
		advtrains.interlocking.signal_readjust_aspect(dst)
	end
end

update_dst = function(dst)
	advtrains.interlocking.signal_readjust_aspect(dst)
end

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
}
