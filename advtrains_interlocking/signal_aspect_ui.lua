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

local function dsel(p, q, x, y)
	if p == nil then
		if q then
			return x
		else
			return y
		end
	elseif p then
		return x
	else
		return y
	end
end

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
	t.main_string = tostring(isasp.main)
	if t.main == nil then
		t.main_string = ""
	end

	t.shunt = {
		attrans("No shunting"),
		attrans("Shunting allowed"),
		attrans("Proceed as main"),
	}

	t.shunt_current = dsel(suppasp.shunt, isasp.shunt, 2, 1)
	if dsel(suppasp.proceed_as_main, isasp.proceed_as_main, t.shunt_current == 1) then
		t.shunt_current = 3
	end
	t.shunt_const = suppasp.shunt ~= nil

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

local function make_signal_aspect_selector_t1(suppasp, purpose, isasp)
	local t = describe_supported_aspects_t1(suppasp, isasp)
	local formmode = 1

	local pos
	if type(purpose) == "table" then
		formmode = 2
		pos = purpose.pos
	end

	local form = {
		"formspec_version[4]",
		string.format("size[8,%f]", ({5.75, 9.25})[formmode]),
		F.S_label(0.5, 0.5, "Select signal aspect"),
	}
	if formmode == 1 then
		form[#form+1] = F.label(0.5, 1, purpose)
	else
		form[#form+1] = F.S_label(0.5, 1, "Signal at @1", minetest.pos_to_string(pos))
	end

	form[#form+1] = F.S_label(0.5, 1.5, "Main aspect")
	if formmode == 1 then
		form[#form+1] = F.field(0.5, 2, 7, "asp_mainval", "", t.main_string)
	else
		form[#form+1] = F.dropdown(0.5, 2, 7, "asp_mainsel", t.main, t.main_current, true)
	end

	form[#form+1] = F.S_label(0.5, 3, "Shunt aspect")
	if formmode == 2 and t.shunt_const then
		form[#form+1] = F.label(0.5, 3.5, t.shunt[t.shunt_current])
		form[#form+1] = F.S_label(0.5, 4, "The shunt aspect cannot be changed.")
	else
		form[#form+1] = F.dropdown(0.5, 3.5, 7, "asp_shunt", t.shunt, t.shunt_current, true)
	end

	form[#form+1] = F.S_button_exit(0.5, 4.5, 7, "asp_save", "Save signal aspect")

	if formmode == 2 then
		form[#form+1] = advtrains.interlocking.make_ip_formspec_component(pos, 0.5, 5.5, 7)
		form[#form+1] = advtrains.interlocking.make_short_dst_formspec_component(pos, 0.5, 7, 7)
	end

	return table.concat(form)
end

local function make_signal_aspect_selector_t2(suppasp, purpose, isasp)
	local def = advtrains.interlocking.aspects.get_type2_definition(suppasp.group)
	if not def then
		return nil
	end
	local formmode = 1

	local pos
	if type(purpose) == "table" then
		formmode = 2
		pos = purpose.pos
	end
	local form = {
		"formspec_version[4]",
		string.format("size[8,%f]", ({4.25, 10.25})[formmode]),
		F.S_label(0.5, 0.5, "Select signal aspect")
	}
	if formmode == 1 then
		form[#form+1] = F.label(0.5, 1, purpose)
	else
		form[#form+1] = F.S_label(0.5, 1, "Signal at @1", minetest.pos_to_string(pos))
	end

	local entries = {}
	local selid = #def.main
	if isasp then
		if isasp.type2name ~= def.main[selid].name then
			selid = 1
		end
	end
	if selid > 1 then
		selid = 2
	end
	local entries = {
		def.main[1].label,
		def.main[#def.main].label,
	}
	form[#form+1] = F.S_label(0.5, 1.5, "Signal group: @1", def.label)
	form[#form+1] = F.dropdown(0.5, 2, 7, "asp_sel", entries, selid, true)
	form[#form+1] = F.S_button_exit(0.5, 3, 7, "asp_save", "Save signal aspect")

	if formmode == 2 then
		form[#form+1] = advtrains.interlocking.make_ip_formspec_component(pos, 0.5, 4, 7)
		form[#form+1] = advtrains.interlocking.make_dst_formspec_component(pos, 0.5, 5.5, 7, 4.25)
	end

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
	minetest.after(0, function()
		players_aspsel[pname] = {
			purpose = purpose,
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

local function get_aspect_from_formspec_t1(suppasp, fields, psl)
	local maini = tonumber(fields.asp_mainsel)
	local main = suppasp.main[maini]
	if not maini then
		local mainval = fields.asp_mainval
		if mainval == "-1" then
			main = -1
		elseif string.match(mainval, "^%d+$") then
			main = tonumber(mainval)
		else
			main = nil
		end
	end
	local shunti = tonumber(fields.asp_shunt)
	local shunt = suppasp.shunt
	if shunt == nil then
		shunt = shunti == 2
	end
	local proceed_as_main = suppasp.proceed_as_main
	if proceed_as_main == nil then
		proceed_as_main = shunti == 3
	end
	return {
		main = main,
		shunt = shunt,
		proceed_as_main = proceed_as_main,
		info = {},
	}
end

local function get_aspect_from_formspec_t2(suppasp, fields, psl)
	local sel = tonumber(fields.asp_sel)
	local def = advtrains.interlocking.aspects.get_type2_definition(suppasp.group)
	if not (sel and def) then
		return
	end
	if sel ~= 1 then
		sel = #def.main
	end
	local asp = advtrains.interlocking.aspects.type2_to_type1(suppasp, sel)
	return asp
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local psl = players_aspsel[pname]
	if psl then
		if formname == "at_il_sigaspdia_"..psl.token then
			local suppasp = psl.suppasp
			if fields.asp_save then
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
			if type(psl.purpose) == "table" then
				local pos = psl.purpose.pos
				advtrains.interlocking.handle_ip_formspec_fields(pname, pos, fields)
				advtrains.interlocking.handle_dst_formspec_fields(pname, pos, fields)
			end
		else
			players_aspsel[pname] = nil
		end
	end
end)
