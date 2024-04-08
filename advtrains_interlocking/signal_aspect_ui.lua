local F = advtrains.formspec
local players_aspsel = {}

local function describe_main_aspect(spv)
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

local function describe_shunt_aspect(shunt)
	if shunt then
		return attrans("Shunting allowed")
	else
		return attrans("No shunting")
	end
end

local function describe_distant_aspect(spv)
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

advtrains.interlocking.describe_main_aspect = describe_main_aspect
advtrains.interlocking.describe_shunt_aspect = describe_shunt_aspect
advtrains.interlocking.describe_distant_aspect = describe_distant_aspect

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

local function describe_supported_aspects(suppasp, isasp)
	local t = {}

	local entries = {attrans("Use default value")}
	local selid = 0
	local mainasps = suppasp.main
	if type(mainasps) ~= "table" then
		mainasps = {mainasps}
	end
	for idx, spv in ipairs(mainasps) do
		if isasp and spv == rawget(isasp, "main") then
			selid = idx
		end
		entries[idx+1] = describe_main_aspect(spv)
	end
	t.main = entries
	t.main_current = selid+1
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

	if suppasp.group then
		local gdef = advtrains.interlocking.aspect.get_group_definition(suppasp.group)
		if gdef then
			t.group = suppasp.group
			t.groupdef = gdef
			local entries = {}
			local selid = 1
			for idx, name in ipairs(suppasp.name or {}) do
				entries[idx] = gdef.aspects[name].label
				if suppasp.group == isasp.group and name == isasp.name then
					selid = idx
				end
			end
			t.name = entries
			t.name_current = selid
		end
	end

	return t
end

advtrains.interlocking.describe_supported_aspects = describe_supported_aspects

local function make_signal_aspect_selector(suppasp, purpose, isasp)
	local t = describe_supported_aspects(suppasp, isasp)
	local formmode = 1

	local pos
	if type(purpose) == "table" then
		formmode = 2
		pos = purpose.pos
	end

	local form = {
		"formspec_version[4]",
		string.format("size[8,%f]", ({5.75, 10.75})[formmode]),
		F.S_label(0.5, 0.5, "Select signal aspect"),
	}
	local h0 = ({0, 1.5})[formmode]
	form[#form+1] = F.S_label(0.5, 1.5+h0, "Main aspect")
	form[#form+1] = F.S_label(0.5, 3+h0, "Shunt aspect")
	form[#form+1] = F.S_button_exit(0.5, 4.5+h0, 7, "asp_save", "Save signal aspect")
	if formmode == 1 then
		form[#form+1] = F.label(0.5, 1, purpose)
		form[#form+1] = F.field(0.5, 2, 7, "asp_mainval", "", t.main_string)
	elseif formmode == 2 then
		if t.group then
			form[#form+1] = F.S_label(0.5, 1.5, "Signal aspect group: @1", t.groupdef.label)
			form[#form+1] = F.dropdown(0.5, 2, 7, "asp_namesel", t.name, t.name_current, true)
		else
			form[#form+1] = F.S_label(0.5, 1.5, "This signal does not belong to a signal aspect group.")
			form[#form+1] = F.S_label(0.5, 2, "You can not use a predefined signal aspect.")
		end
		form[#form+1] = F.S_label(0.5, 1, "Signal at @1", minetest.pos_to_string(pos))
		form[#form+1] = F.dropdown(0.5, 3.5, 7, "asp_mainsel", t.main, t.main_current, true)
		form[#form+1] = advtrains.interlocking.make_ip_formspec_component(pos, 0.5, 7, 7)
		form[#form+1] = advtrains.interlocking.make_short_dst_formspec_component(pos, 0.5, 8.5, 7)
	end

	if formmode == 2 and t.shunt_const then
		form[#form+1] = F.label(0.5, 3.5+h0, t.shunt[t.shunt_current])
		form[#form+1] = F.S_label(0.5, 4+h0, "The shunt aspect cannot be changed.")
	else
		form[#form+1] = F.dropdown(0.5, 3.5+h0, 7, "asp_shunt", t.shunt, t.shunt_current, true)
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
	local pos
	if type(p_purpose) == "table" then
		pos = p_purpose
		purpose = {pname = pname, pos = pos}
	end

	local form = make_signal_aspect_selector(suppasp, purpose, isasp)
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

local function get_aspect_from_formspec(suppasp, fields, psl)
	local namei, group, name = tonumber(fields.asp_namesel), suppasp.group, nil
	local gdef = advtrains.interlocking.aspect.get_group_definition(group)
	if gdef then
		local names = suppasp.name or {}
		name = names[namei] or names[names]
	else
		group = nil
	end
	local maini = tonumber(fields.asp_mainsel)
	local main = (suppasp.main or {})[(maini or 0)-1]
	if not maini then
		local mainval = fields.asp_mainval
		if mainval == "-1" then
			main = -1
		elseif mainval == "x" then
			main = false
		elseif string.match(mainval, "^%d+$") then
			main = tonumber(mainval)
		else
			main = nil
		end
	elseif maini <= 1 then
		main = nil
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
	return advtrains.interlocking.aspect {
		main = main,
		shunt = shunt,
		proceed_as_main = proceed_as_main,
		info = {},
		name = name,
		group = group,
	}
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local psl = players_aspsel[pname]
	if psl then
		if formname == "at_il_sigaspdia_"..psl.token then
			local suppasp = psl.suppasp
			if fields.asp_save then
				local asp
				asp = get_aspect_from_formspec(suppasp, fields, psl)
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
