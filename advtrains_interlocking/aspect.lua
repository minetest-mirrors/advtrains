--- Signal aspect handling.
-- @module advtrains.interlocking.aspect

local registered_groups = {}

local default_aspect = {
	main = false,
	dst = false,
	shunt = true,
	proceed_as_main = false,
}

local signal_aspect = {}

local signal_aspect_metatable = {
	__eq = function(asp1, asp2)
		for _, k in pairs {"main", "dst", "shunt", "proceed_as_main"} do
			local v1, v2 = (asp1[k] or false), (asp2[k] or false)
			if v1 ~= v2 then
				return false
			end
		end
		if asp1.group and asp1.group == asp2.group then
			return asp1.name == asp2.name
		end
		return true
	end,
	__index = function(asp, field)
		local val = signal_aspect[field]
		if val then
			return val
		end
		val = default_aspect[field]
		if val == nil then
			return nil
		end
		local group = registered_groups[rawget(asp, "group")]
		if group then
			local aspdef = group.aspects[rawget(asp, "name")]
			if aspdef[field] ~= nil then
				val = aspdef[field]
			end
		end
		return val
	end,
	__tostring = function(asp)
		local st = {}
		if asp.group and asp.name then
			table.insert(st, ("%q in %q"):format(asp.name, asp.group))
		end
		if asp.main then
			table.insert(st, ("current %d"):format(asp.main))
		end
		if asp.main ~= 0 then
			if asp.dst then
				table.insert(st, string.format("next %d", asp.dst))
			end
		end
		if asp.main ~= 0 and asp.proceed_as_main then
			table.insert(st, "proceed as main")
		end
		return ("[%s]"):format(table.concat(st, ", "))
	end,
}

local function quicknew(t)
	return setmetatable(t, signal_aspect_metatable)
end

--- Signal aspect class.
-- @type signal_aspect

--- Return a plain version of the signal aspect.
-- @param[opt=false] raw Bypass metamethods when fetching signal aspects
-- @return A plain copy of the signal aspect object.
function signal_aspect:plain(raw)
	local t = {}
	for _, k in pairs {"main", "dst", "shunt", "proceed_as_main", "group", "name"} do
		local v
		if raw then
			v = rawget(self, k)
		else
			v = self[k]
		end
		t[k] = v
	end
	return t
end

--- Create (or copy) a signal aspect object.
-- Note that signal aspect objects can also be created by calling the `advtrains.interlocking.aspect` table.
-- @return The newly created signal aspect object.
function signal_aspect:new()
	if type(self) ~= "table" then
		return quicknew{}
	end
	local newasp = {}
	for _, k in pairs {"main", "dst"} do
		if type(self[k]) == "table" then
			if self[k].free then
				newasp[k] = self[k].speed
			else
				newasp[k] = 0
			end
		else
			newasp[k] = self[k]
		end
	end
	if type(self.shunt) == "table" then
		newasp.shunt = self.shunt.free
		newasp.proceed_as_main = self.shunt.proceed_as_main
	else
		newasp.shunt = self.shunt
	end
	for _, k in pairs {"group", "name"} do
		newasp[k] = self[k]
	end
	return quicknew(newasp)
end

--- Modify the signal aspect in-place to fit in the specific signal group.
-- @param group The signal group. The `nil` indicates a generic group.
-- @return The (now modified) signal aspect itself.
function signal_aspect:to_group(group)
	local cg = self.group
	local gdef = registered_groups[group]
	if type(self.name) ~= "string" then
		self.name = nil
	end
	if not gdef then
		for k in pairs(default_aspect) do
			rawset(self, k, self[k])
		end
		self.group = nil
		self.name = nil
		return self
	elseif cg == group and gdef.aspects[self.name] then
		return self
	end
	local newidx = 1
	if self.main == 0 then
		newidx = #gdef.aspects
	end
	local cgdef = registered_groups[cg]
	if cgdef then
		local idx = (cgdef.aspects[self.name] or {}).index
		if idx then
			if idx >= #cgdef.aspects then
				idx = #gdef.aspects
			elseif idx >= #gdef.aspects then
				idx = #gdef.aspects-1
			end
			newidx = idx
		end
	end
	self.group = group
	self.name = gdef.aspects[newidx][1]
	return self
end

--- Modify the signal aspect in-place to indicate a specific distant aspect.
-- @param dst The distant aspect
-- @param[opt=1] shift The phase shift of the current signal.
-- @return The (now modified) signal aspect itself.
function signal_aspect:adjust_distant(dst, shift)
	if (shift or -1) < 0 then
		shift = 1
	end
	if not dst then
		self.dst = nil
		return self
	end
	if self.main ~= 0 then
		self.dst = dst.main
	else
		self.dst = nil
		return self
	end
	local dgdef = registered_groups[dst.group]
	if dgdef then
		if self.group == dst.group and shift == 0 then
			self.name = dst.name
		else
			local idx = (dgdef.aspects[dst.name] or {}).index
			if idx then
				idx = math.max(idx-shift, 1)
				self.group = dst.group
				self.name = dgdef.aspects[idx][1]
			end
		end
	end
	return self
end

--- Signal groups.
-- @section signal_group

--- Register a signal group.
-- @function register_group
-- @param def The definition table.
local function register_group(def)
	local t = {}
	local name = def.name
	if type(name) ~= "string" then
		return error("Expected signal group name to be a string, got " .. type(name))
	elseif registered_groups[name] then
		return error(string.format("Attempt to redefine signal group %q, previously defined in %s", name, registered_groups[name].defined))
	end
	t.name = name

	t.defined = debug.getinfo(2, "S").short_src or "[?]"

	local label = def.label or name
	if type(label) ~= "string" then
		return error("Label is not a string")
	end
	t.label = label

	local mainasps = {}
	for idx, asp in pairs(def.aspects) do
		local idxtp = type(idx)
		if idxtp == "string" then
			local t = {}
			t.name = idx

			local label = asp.label or idx
			if type(label) ~= "string" then
				return error("Aspect label is not a string")
			end
			t.label = label

			for _, k in pairs{"main", "dst", "shunt"} do
				t[k] = asp[k]
			end

			mainasps[idx] = t
		end
	end
	if #def.aspects < 2 then
		return error("Insufficient entries in signal aspect list")
	end
	for idx, asplist in ipairs(def.aspects) do
		if type(asplist) ~= "table" then
			asplist = {asplist}
		else
			asplist = table.copy(asplist)
		end
		if #asplist < 1 then
			error("Invalid entry in signal aspect list")
		end
		for _, k in ipairs(asplist) do
			if type(k) ~= "string" then
				return error("Invalid signal aspect ID")
			end
			local asp = mainasps[k]
			if not asp then
				return error("Invalid signal aspect ID")
			end
			if asp.index ~= nil then
				return error("Attempt to assign a signal aspect to multiple numeric indices")
			end
			asp.index = idx
		end
		mainasps[idx] = asplist
	end
	t.aspects = mainasps

	registered_groups[name] = t
end

--- Get the definition of a signal group.
-- @function get_group_definition
-- @param name The name of the signal group.
-- @return[1] The definition for the signal group (if present).
-- @return[2] The nil constant (otherwise).
local function get_group_definition(name)
	local t = registered_groups[name]
	if t then
		return table.copy(t)
	else
		return nil
	end
end

local lib = {
	register_group = register_group,
	get_group_definition = get_group_definition,
}

local libmt = {
	__call = function(_, ...)
		return signal_aspect.new(...)
	end,
}

return setmetatable(lib, libmt)
