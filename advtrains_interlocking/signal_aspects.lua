local type2defs = {}

local function register_type2(def)
	local t = {type = 2}
	local name = def.name
	if type2defs[name] then
		return error("Name " .. name .. " already used")
	elseif type(name) ~= "string" then
		return error("Name is not a string")
	end
	t.name = name

	local label = def.label or name
	if type(label) ~= "string" then
		return error("Label is not a string")
	end
	t.label = label

	local mainasps = {}
	for idx, asp in ipairs(def.main) do
		local t = {}
		local name = asp.name
		if type(name) ~= "string" then
			return error("Aspect name is not a string")
		end
		t.name = name

		local label = asp.label or name
		if type(label) ~= "string" then
			return error("Aspect label is not a string")
		end
		t.label = label

		t.main = asp.main
		mainasps[idx] = t
		mainasps[name] = idx
	end
	t.main = mainasps

	type2defs[name] = t
end

local function get_type2_definition(name)
	return type2defs[name]
end

local function type2main_to_type1(name, asp)
	local def = type2defs[name]
	if not def then
		return nil
	end
	local aspidx
	if type(asp) == "number" then
		aspidx = asp
	else
		aspidx = def.main[asp]
	end
	local asptbl = def.main[aspidx]
	if not asptbl then
		return nil
	end
	if type(asp) == "number" then
		asp = asptbl.name
	end

	local t = {
		main = asptbl.main,
		type2name = asp,
		type2group = name,
	}
	if aspidx > 1 and aspidx < #asptbl then
		t.dst = asptbl[aspidx+1].main
	end
	return t
end

local function type1_to_type2main(asp, group)
	local def = type2defs[group]
	if not def then
		return nil
	end
	if group == asp.type2group and def.main[asp.type2name] then
		return asp.type2name
	end
	local t_main = def.main
	local idx
	if not asp.main or asp.main == -1 then
		idx = 1
	elseif asp.main == 0 then
		idx = #t_main
	else
		idx = math.max(#t_main-1, 1)
	end
	return t_main[idx].name
end

local function equalp(asp1, asp2)
	if asp1 == asp2 then -- same reference
		return true
	elseif asp1.type2group and asp1.type2group == asp2.type2group then -- type2 with the same group
		return asp1.type2name == asp2.type2name
	else
		for _, k in pairs {"main", "shunt", "dst"} do
			if asp1[k] ~= asp2[k] then
				return false
			end
		end
	end
	return true
end

local function not_equalp(asp1, asp2)
	return not equalp(asp1, asp2)
end

return {
	register_type2 = register_type2,
	get_type2_definition = get_type2_definition,
	type2main_to_type1 = type2main_to_type1,
	type1_to_type2main = type1_to_type2main,
	equalp = equalp,
	not_equalp = not_equalp,
}
