local F = advtrains.formspec
local players_aspsel = {}

local function make_signal_aspect_selector_t1(suppasp, purpose, isasp)
	local form = {"size[7,7.5]"}
	form[#form+1] = F.S_label(0.5, 0.5, "Select signal aspect")
	form[#form+1] = F.label(0.5, 1, purpose)

	form[#form+1] = F.S_label(0.5, 1.5, "Main aspect")
	local entries = {}
	local selid = 1
	for idx, spv in ipairs(suppasp.main) do
		local entry
		if isasp and spv == isasp.main then
			selid = idx
		end
		if spv == 0 then
			entry = attrans("Danger (halt)")
		elseif spv == -1 then
			entry = attrans("Continue at maximum speed")
		elseif not spv then
			entry = attrans("Continue with current speed limit")
		else
			entry = attrans("Continue with the speed limit of @1", spv)
		end
		entries[idx] = entry
	end
	form[#form+1] = F.dropdown(0.5, 2, 6, "main", entries, selid, true)

	form[#form+1] = F.S_label(0.5, 3, "Shunt aspect")
	if suppasp.shunt == nil then
		local st = 1
		if isasp and isasp.shunt then st = 2 end
		local entries = {
			attrans("No shunting"),
			attrans("Shunting allowed"),
		}
		form[#form+1] = F.dropdown(0.5, 3.5, 6, "shunt_free", entries, st, true)
	end

	form[#form+1] = F.S_label(0.5, 4.5, "Distant aspect")
	local entries = {}
	local selid = 1
	for idx, spv in ipairs(suppasp.dst) do
		local entry
		if isasp and spv == isasp.dst then
			selid = idx
		end
		if spv == 0 then
			entry = attrans("Expect to stop at the next signal")
		elseif spv == -1 then
			entry = attrans("Expect to continue at maximum speed")
		elseif not spv then
			entry = attrans("No information on distant signal")
		else
			entry = attrans("Expect to continue with a speed limit of @1", spv)
		end
		entries[idx] = entry
	end
	form[#form+1] = F.dropdown(0.5, 5, 6, "dst", entries, selid, true)

	form[#form+1] = F.S_button_exit(0.5, 6, 6, 1, "save", "Save signal aspect")
	return table.concat(form)
end

local function make_signal_aspect_selector_t2(suppasp, purpose, isasp)
	local form = {"size[7,4]"}
	local def = advtrains.interlocking.aspects.get_type2_definition(suppasp.group)
	if not def then
		return nil
	end
	form[#form+1] = F.S_label(0.5, 0.5, "Select signal aspect")
	form[#form+1] = F.label(0.5, 1, purpose)

	local entries = {}
	local selid = 1
	for idx, spv in ipairs(def.main) do
		if isasp and isasp.type2name == spv.name then
			selid = idx
		end
		entries[idx] = spv.label
	end
	form[#form+1] = F.dropdown(0.5, 1.5, 6, "asp", entries, selid, true)
	form[#form+1] = F.S_button_exit(0.5, 2.5, 6, 1, "save", "Save signal aspect")
	return table.concat(form)
end

function advtrains.interlocking.show_signal_aspect_selector(pname, p_suppasp, p_purpose, callback, isasp)
	local suppasp = p_suppasp or {
		main = {0, -1},
		dst = {false},
		shunt = false,
		info = {},
	}
	local purpose = p_purpose or ""

	local form
	if suppasp.type == 2 then
		form = make_signal_aspect_selector_t2(suppasp, purpose, isasp)
	else
		form = make_signal_aspect_selector_t1(suppasp, purpose, isasp)
	end
	if not form then
		return
	end

	local token = advtrains.random_id()
	minetest.show_formspec(pname, "at_il_sigaspdia_"..token, form)
	minetest.after(1, function()
	players_aspsel[pname] = {
		suppasp = suppasp,
		callback = callback,
		token = token,
	}
	end)
end

local function usebool(sup, val, free)
	if sup == nil then
		return val == free
	else
		return sup
	end
end

local function get_aspect_from_formspec_t1(suppasp, fields)
	local maini = tonumber(fields.main)
	if not maini then return end
	local dsti = tonumber(fields.dst)
	if not dsti then return end
	return {
		main = suppasp.main[maini],
		dst = suppasp.dst[dsti],
		shunt = usebool(suppasp.shunt, fields.shunt_free, "2"),
		info = {},
	}
end

local function get_aspect_from_formspec_t2(suppasp, fields)
	local asp = advtrains.interlocking.aspects.type2main_to_type1(suppasp.group, tonumber(fields.asp))
	return asp
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local psl = players_aspsel[pname]
	if psl then
		if formname == "at_il_sigaspdia_"..psl.token then
			local suppasp = psl.suppasp
			if fields.save then
				local asp
				if suppasp.type == 2 then
					asp = get_aspect_from_formspec_t2(suppasp, fields)
				else
					asp = get_aspect_from_formspec_t1(suppasp, fields)
				end
				if asp then
					psl.callback(pname, asp)
				end
			end
		else
			players_aspsel[pname] = nil
		end
	end
end)
