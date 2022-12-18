local F = advtrains.formspec
local players_aspsel = {}

local function describe_t1_main_aspect(spv)
	if spv == 0 then
		return attrans("Danger (halt)")
	elseif spv == -1 then
		return attrans("Continue at maximum speed")
	elseif not spv then
		return attrans("Continue with current speed limit")
	else
		return attrans("Continue with the speed limit of @1", tostring(spv))
	end
end

local function describe_t1_shunt_aspect(shunt)
	if shunt then
		return attrans("Shunting allowed")
	else
		return attrans("No shunting")
	end
end

local function describe_t1_distant_aspect(spv)
	if spv == 0 then
		return attrans("Expect to stop at the next signal")
	elseif spv == -1 then
		return attrans("Expect to continue at maximum speed")
	elseif not spv then
		return attrans("No distant signal information")
	else
		return attrans("Expect to continue with a speed limit of @1", tostring(spv))
	end
end

advtrains.interlocking.describe_t1_main_aspect = describe_t1_main_aspect
advtrains.interlocking.describe_t1_shunt_aspect = describe_t1_shunt_aspect
advtrains.interlocking.describe_t1_distant_aspect = describe_t1_distant_aspect

local function describe_supported_aspects_t1(suppasp, isasp)
	local t = {}

	local entries = {}
	local selid = 1
	for idx, spv in ipairs(suppasp.main) do
		if isasp and spv == (isasp.main or false) then
			selid = idx
		end
		entries[idx] = describe_t1_main_aspect(spv)
	end
	t.main = entries
	t.main_current = selid

	if suppasp.shunt == nil then
		t.shunt = true
		t.shunt_current = isasp and isasp.shunt
	end

	entries = {}
	selid = 1
	for idx, spv in ipairs(suppasp.dst) do
		if isasp and spv == (isasp.dst or false) then
			selid = idx
		end
		entries[idx] = describe_t1_distant_aspect(spv)
	end
	t.dst = entries
	t.dst_current = selid
	return t
end

advtrains.interlocking.describe_supported_aspects_t1 = describe_supported_aspects_t1

local signal_tabheader_map = {}

local function make_signal_formspec_tabheader(pname, pos, width, selid)
	signal_tabheader_map[pname] = pos
	local firstlabel = attrans("Signal aspect")
	if advtrains.interlocking.db.get_sigd_for_signal(pos) then
		firstlabel = attrans("Routesetting")
	end
	local options = {
		firstlabel,
		attrans("Influence point"),
		attrans("Distant signalling"),
	}
	return F.tabheader(0, 0, nil, nil, "signal_tab", options, selid)
end

local function handle_signal_formspec_tabheader_fields(pname, fields)
	local n = tonumber(fields.signal_tab)
	local pos = signal_tabheader_map[pname]
	if not (n and pos) then
		return false
	end
	if n == 1 then
		local node = advtrains.ndb.get_node(pos)
		advtrains.interlocking.show_signal_form(pos, node, pname)
	elseif n == 2 then
		advtrains.interlocking.show_ip_form(pos, pname)
	elseif n == 3 then
		advtrains.interlocking.show_distant_signal_form(pos, pname)
	end
	return true
end

advtrains.interlocking.make_signal_formspec_tabheader = make_signal_formspec_tabheader
advtrains.interlocking.handle_signal_formspec_tabheader_fields = handle_signal_formspec_tabheader_fields

local function make_signal_aspect_selector_t1(suppasp, purpose, isasp)
	local form = {"size[7,6.5]"}
	local t = describe_supported_aspects_t1(suppasp, isasp)
	if type(purpose) == "table" then
		form[#form+1] = make_signal_formspec_tabheader(purpose.pname, purpose.pos, 7, 1)
		purpose = ""
	end
	form[#form+1] = F.S_label(0.5, 0.5, "Select signal aspect")
	form[#form+1] = F.label(0.5, 1, purpose)

	form[#form+1] = F.S_label(0.5, 1.5, "Main aspect")
	form[#form+1] = F.dropdown(0.5, 2, 6, "main", t.main, t.main_current, true)

	form[#form+1] = F.S_label(0.5, 3, "Distant aspect")
	form[#form+1] = F.dropdown(0.5, 3.5, 6, "dst", t.dst, t.dst_current, true)

	if t.shunt then
		form[#form+1] = F.S_checkbox(0.5, 4.25, "shunt", t.shunt_current, "Allow shunting")
	else
		form[#form+1] = F.S_label(0.5, 4.5, "The shunt aspect cannot be changed.")
	end

	form[#form+1] = F.S_button_exit(0.5, 5.25, 6, 1, "save", "Save signal aspect")
	return table.concat(form)
end

local function make_signal_aspect_selector_t2(suppasp, purpose, isasp)
	local form = {"size[7,6.5]"}
	local def = advtrains.interlocking.aspects.get_type2_definition(suppasp.group)
	if not def then
		return nil
	end
	if type(purpose) == "table" then
		form[#form+1] = make_signal_formspec_tabheader(purpose.pname, purpose.pos, 7, 1)
		purpose = ""
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
	form[#form+1] = F.S_label(0.5, 1.5, "Signal group: @1", def.label)
	form[#form+1] = F.dropdown(0.5, 2, 6, "asp", entries, selid, true)
	form[#form+1] = F.S_label(0.5, 3, "Aspect in effect:")
	form[#form+1] = F.label(0.5, 3.5, describe_t1_main_aspect(isasp.main))
	form[#form+1] = F.label(0.5, 4, describe_t1_distant_aspect(isasp.dst))
	form[#form+1] = F.label(0.5, 4.5, describe_t1_shunt_aspect(isasp.shunt))
	form[#form+1] = F.S_button_exit(0.5, 5.25, 6, 1, "save", "Save signal aspect")
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
	if type(p_purpose) == "table" then
		purpose = {pname = pname, pos = p_purpose}
	end

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
	--minetest.after(1, function()
	players_aspsel[pname] = {
		suppasp = suppasp,
		callback = callback,
		token = token,
	}
	--end)
end

local function usebool(sup, val, free)
	if sup == nil then
		return val == free
	else
		return sup
	end
end

local function get_aspect_from_formspec_t1(suppasp, fields, psl)
	local maini = tonumber(fields.main)
	if not maini then return end
	local dsti = tonumber(fields.dst)
	if not dsti then return end
	return {
		main = suppasp.main[maini],
		dst = suppasp.dst[dsti],
		shunt = usebool(suppasp.shunt, psl.shunt, "true"),
		info = {},
	}
end

local function get_aspect_from_formspec_t2(suppasp, fields, psl)
	local asp = advtrains.interlocking.aspects.type2_to_type1(suppasp, tonumber(fields.asp))
	return asp
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local psl = players_aspsel[pname]
	if psl then
		if formname == "at_il_sigaspdia_"..psl.token then
			local suppasp = psl.suppasp
			if handle_signal_formspec_tabheader_fields(pname, fields) then
				return true
			end
			if fields.shunt then
				psl.shunt = fields.shunt
			end
			if fields.save then
				local asp
				if suppasp.type == 2 then
					asp = get_aspect_from_formspec_t2(suppasp, fields, psl)
				else
					asp = get_aspect_from_formspec_t1(suppasp, fields, psl)
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
