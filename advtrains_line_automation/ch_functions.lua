--advtrains_line_automation

-- Functions from Cesky Hvozd utility libraries which are used in the code integrated from Singularis are now provided here.

--[[
Jednoduchá funkce, která vyhodnotí condition jako podmínku
a podle výsledku vrátí buď true_result, nebo false_result.
]]
local function ifthenelse(condition, true_result, false_result)
	if condition then
		return true_result
	else
		return false_result
	end
end

local ch_core = {}

-- gives various info about a player. we return only what is relevant outside CH
function ch_core.normalize_player(player_name_or_player)
	local arg_type = type(player_name_or_player)
	local player_name, player
	if arg_type == "string" then
		player_name = player_name_or_player
	elseif arg_type == "number" then
		player_name = tostring(player_name_or_player)
	elseif (arg_type == "table" or arg_type == "userdata") and type(player_name_or_player.get_player_name) == "function" then
		player_name = player_name_or_player:get_player_name()
		if type(player_name) ~= "string" then
			player_name = ""
		else
			if minetest.is_player(player_name_or_player) then
				player = player_name_or_player
			end
		end
	else
		player_name = ""
	end
	if player_name == "" then
		return {role = "none", player_name = "", viewname = "", privs = {}}
	end
	local privs = minetest.get_player_privs(player_name)
	return {
		role = "default",
		player_name = player_name,
		viewname = player_name,
		privs = privs,
		player = player or minetest.get_player_by_name(player_name),
	}
end

-- == UTF8 helpers == --

local utf8_charlen = {}
for i = 1, 191, 1 do
	-- 1 to 127 => jednobajtové znaky
	-- 128 až 191 => nejsou dovoleny jako první bajt (=> vrátit 1 bajt)
	utf8_charlen[i] = 1
end
for i = 192, 223, 1 do
	utf8_charlen[i] = 2
end
for i = 224, 239, 1 do
	utf8_charlen[i] = 3
end
for i = 240, 247, 1 do
	utf8_charlen[i] = 4
end
for i = 248, 255, 1 do
	utf8_charlen[i] = 1 -- neplatné UTF-8
end

local utf8_sort_data_1 = {
  ["\x20"] = "\x20", -- < >
  ["\x21"] = "\x21", -- <!>
  ["\x22"] = "\x22", -- <">
  ["\x23"] = "\x23", -- <#>
  ["\x25"] = "\x24", -- <%>
  ["\x26"] = "\x25", -- <&>
  ["\x27"] = "\x26", -- <'>
  ["\x28"] = "\x27", -- <(>
  ["\x29"] = "\x28", -- <)>
  ["\x2a"] = "\x29", -- <*>
  ["\x2b"] = "\x2a", -- <+>
  ["\x2c"] = "\x2b", -- <,>
  ["\x2d"] = "\x2c", -- <->
  ["\x2e"] = "\x2d", -- <.>
  ["\x2f"] = "\x2e", -- </>
  ["\x3a"] = "\x2f", -- <:>
  ["\x3b"] = "\x30", -- <;>
  ["\x3c"] = "\x31", -- <<>
  ["\x3d"] = "\x32", -- <=>
  ["\x3e"] = "\x33", -- <>>
  ["\x3f"] = "\x34", -- <?>
  ["\x40"] = "\x35", -- <@>
  ["\x5b"] = "\x36", -- <[>
  ["\x5c"] = "\x37", -- <\>
  ["\x5d"] = "\x38", -- <]>
  ["\x5e"] = "\x39", -- <^>
  ["\x5f"] = "\x3a", -- <_>
  ["\x60"] = "\x3b", -- <`>
  ["\x7b"] = "\x3c", -- <{>
  ["\x7c"] = "\x3d", -- <|>
  ["\x7d"] = "\x3e", -- <}>
  ["\x7e"] = "\x3f", -- <~>
  ["\x24"] = "\x40", -- <$>
  ["\x61"] = "\x41", -- <a>
  ["\x41"] = "\x42", -- <A>
  ["\x62"] = "\x47", -- <b>
  ["\x42"] = "\x48", -- <B>
  ["\x64"] = "\x4d", -- <d>
  ["\x44"] = "\x4e", -- <D>
  ["\x65"] = "\x51", -- <e>
  ["\x45"] = "\x52", -- <E>
  ["\x66"] = "\x57", -- <f>
  ["\x46"] = "\x58", -- <F>
  ["\x67"] = "\x59", -- <g>
  ["\x47"] = "\x5a", -- <G>
  ["\x68"] = "\x5b", -- <h>
  ["\x48"] = "\x5c", -- <H>
  ["\x69"] = "\x61", -- <i>
  ["\x49"] = "\x62", -- <I>
  ["\x6a"] = "\x65", -- <j>
  ["\x4a"] = "\x66", -- <J>
  ["\x6b"] = "\x67", -- <k>
  ["\x4b"] = "\x68", -- <K>
  ["\x6c"] = "\x69", -- <l>
  ["\x4c"] = "\x6a", -- <L>
  ["\x6d"] = "\x6f", -- <m>
  ["\x4d"] = "\x70", -- <M>
  ["\x6e"] = "\x71", -- <n>
  ["\x4e"] = "\x72", -- <N>
  ["\x6f"] = "\x75", -- <o>
  ["\x4f"] = "\x76", -- <O>
  ["\x70"] = "\x7b", -- <p>
  ["\x50"] = "\x7c", -- <P>
  ["\x71"] = "\x7d", -- <q>
  ["\x51"] = "\x7e", -- <Q>
  ["\x72"] = "\x7f", -- <r>
  ["\x52"] = "\x80", -- <R>
  ["\x73"] = "\x85", -- <s>
  ["\x53"] = "\x86", -- <S>
  ["\x74"] = "\x89", -- <t>
  ["\x54"] = "\x8a", -- <T>
  ["\x75"] = "\x8d", -- <u>
  ["\x55"] = "\x8e", -- <U>
  ["\x76"] = "\x93", -- <v>
  ["\x56"] = "\x94", -- <V>
  ["\x77"] = "\x95", -- <w>
  ["\x57"] = "\x96", -- <W>
  ["\x78"] = "\x97", -- <x>
  ["\x58"] = "\x98", -- <X>
  ["\x79"] = "\x99", -- <y>
  ["\x59"] = "\x9a", -- <Y>
  ["\x7a"] = "\x9d", -- <z>
  ["\x5a"] = "\x9e", -- <Z>
  ["\x30"] = "\xa1", -- <0>
  ["\x31"] = "\xa2", -- <1>
  ["\x32"] = "\xa3", -- <2>
  ["\x33"] = "\xa4", -- <3>
  ["\x34"] = "\xa5", -- <4>
  ["\x35"] = "\xa6", -- <5>
  ["\x36"] = "\xa7", -- <6>
  ["\x37"] = "\xa8", -- <7>
  ["\x38"] = "\xa9", -- <8>
  ["\x39"] = "\xaa", -- <9>
}

local utf8_sort_data_2 = {
  ["\xc3\xa1"] = "\x43", -- <á>
  ["\xc3\x81"] = "\x44", -- <Á>
  ["\xc3\xa4"] = "\x45", -- <ä>
  ["\xc3\x84"] = "\x46", -- <Ä>
  ["\xc4\x8d"] = "\x4b", -- <č>
  ["\xc4\x8c"] = "\x4c", -- <Č>
  ["\xc4\x8f"] = "\x4f", -- <ď>
  ["\xc4\x8e"] = "\x50", -- <Ď>
  ["\xc3\xa9"] = "\x53", -- <é>
  ["\xc3\x89"] = "\x54", -- <É>
  ["\xc4\x9b"] = "\x55", -- <ě>
  ["\xc4\x9a"] = "\x56", -- <Ě>
  ["\x63\x68"] = "\x5d", -- <ch>
  ["\x63\x48"] = "\x5e", -- <cH>
  ["\x43\x68"] = "\x5f", -- <Ch>
  ["\x43\x48"] = "\x60", -- <CH>
  ["\xc3\xad"] = "\x63", -- <í>
  ["\xc3\x8d"] = "\x64", -- <Í>
  ["\xc4\xba"] = "\x6b", -- <ĺ>
  ["\xc4\xb9"] = "\x6c", -- <Ĺ>
  ["\xc4\xbe"] = "\x6d", -- <ľ>
  ["\xc4\xbd"] = "\x6e", -- <Ľ>
  ["\xc5\x88"] = "\x73", -- <ň>
  ["\xc5\x87"] = "\x74", -- <Ň>
  ["\xc3\xb3"] = "\x77", -- <ó>
  ["\xc3\x93"] = "\x78", -- <Ó>
  ["\xc3\xb4"] = "\x79", -- <ô>
  ["\xc3\x94"] = "\x7a", -- <Ô>
  ["\xc5\x95"] = "\x81", -- <ŕ>
  ["\xc5\x94"] = "\x82", -- <Ŕ>
  ["\xc5\x99"] = "\x83", -- <ř>
  ["\xc5\x98"] = "\x84", -- <Ř>
  ["\xc5\xa1"] = "\x87", -- <š>
  ["\xc5\xa0"] = "\x88", -- <Š>
  ["\xc5\xa5"] = "\x8b", -- <ť>
  ["\xc5\xa4"] = "\x8c", -- <Ť>
  ["\xc3\xba"] = "\x8f", -- <ú>
  ["\xc3\x9a"] = "\x90", -- <Ú>
  ["\xc5\xaf"] = "\x91", -- <ů>
  ["\xc5\xae"] = "\x92", -- <Ů>
  ["\xc3\xbd"] = "\x9b", -- <ý>
  ["\xc3\x9d"] = "\x9c", -- <Ý>
  ["\xc5\xbe"] = "\x9f", -- <ž>
  ["\xc5\xbd"] = "\xa0", -- <Ž>
}

local utf8_sort_data_3 = {
  ["\x63"] = "\x49", -- <c>
  ["\x43"] = "\x4a", -- <C>
}

--[[
Vrátí počet UTF-8 znaků řetězce.
]]
function ch_core.utf8_length(s)
	if s == "" then
		return 0
	end
	local i, byte, bytes, chars
	i = 1
	chars = 0
	bytes = string.len(s)
	while i <= bytes do
		byte = string.byte(s, i)
		if byte < 192 then
			i = i + 1
		else
			i = i + utf8_charlen[byte]
		end
		chars = chars + 1
	end
	return chars
end

--[[
Začne v řetězci `s` na fyzickém indexu `i` a bude se posouvat o `seek`
UTF-8 znaků doprava (pro záporný počet doleva); vrátí výsledný index
(na první bajt znaku), nebo nil, pokud posun přesáhl začátek,
resp. konec řetězce.
]]
function ch_core.utf8_seek(s, i, seek)
	local bytes = string.len(s)
	if i < 1 or i > bytes then
		return nil
	end
	local b
	if seek > 0 then
		while true do
			b = string.byte(s, i)
			if b < 192 then
				i = i + 1
			else
				i = i + utf8_charlen[b]
			end
			if i > bytes then
				return nil
			end
			seek = seek - 1
			if seek == 0 then
				return i
			end
		end
	elseif seek < 0 then
		while true do
			i = i - 1
			if i < 1 then
				return nil
			end
			b = string.byte(s, i)
			if b < 128 or b >= 192 then
				-- máme další znak
				seek = seek + 1
				if seek == 0 then
					return i
				end
			end
		end
	else
		return i
	end
end

--[[
	Je-li řetězec s delší než max_chars znaků, vrátí jeho prvních max_chars znaků
	+ "...", jinak vrátí původní řetězec.
]]
function ch_core.utf8_truncate_right(s, max_chars, dots_string)
	local i = ch_core.utf8_seek(s, 1, max_chars)
	if i then
		return s:sub(1, i - 1) .. (dots_string or "...")
	else
		return s
	end
end

--[[
Rozdělí řetězec na pole neprázdných podřetězců o stanovené maximální délce
v UTF-8 znacích; v každé části vynechává mezery na začátku a na konci části;
přednostně dělí v místech mezer. Pro prázdný řetězec
(nebo řetězec tvořený jen mezerami) vrací prázdné pole.
]]
function ch_core.utf8_wrap(s, max_chars, options)
	local i = 1 		-- index do vstupního řetězce s
	local s_bytes = string.len(s)
	local result = {}	-- výstupní pole
	local r_text = ""	-- výstupní řetězec
	local r_chars = 0	-- počet UTF-8 znaků v řetězci r
	local r_sp_begin	-- index první mezery v poslední sekvenci mezer v r_text
	local r_sp_end		-- index poslední mezery v poslední sekvenci mezer v r_text
	local b				-- kód prvního bajtu aktuálního znaku
	local c_bytes		-- počet bajtů aktuálního znaku

	-- options
	local allow_empty_lines, max_result_lines, line_separator
	if options then
		allow_empty_lines = options.allow_empty_lines -- true or false
		max_result_lines = options.max_result_lines -- nil or number
		line_separator = options.line_separator -- nil or string
	end

	while i <= s_bytes do
		b = string.byte(s, i)
		-- print("byte["..i.."] = "..b.." ("..s:sub(i, i)..") r_sp = ("..(r_sp_begin or "nil")..".."..(r_sp_end or "nil")..")")
		if r_chars > 0 or (b ~= 32 and (b ~= 10 or allow_empty_lines)) then -- na začátku řádky ignorovat mezery
			if b < 192 then
				c_bytes = 1
			else
				c_bytes = utf8_charlen[b]
			end
			-- vložit do r další znak (není-li to konec řádky)
			if b ~= 10 then
				r_text = r_text..s:sub(i, i + c_bytes - 1)
				r_chars = r_chars + 1

				if b == 32 then
					-- znak je mezera
					if r_sp_begin then
						if r_sp_end then
							-- začátek nové skupiny mezer (už nějaká byla)
							r_sp_begin = string.len(r_text)
							r_sp_end = nil
						end
					elseif not r_sp_end then
						-- začátek první skupiny mezer (ještě žádná nebyla)
						r_sp_begin = string.len(r_text)
					end
				else
					-- znak není mezera ani konec řádky
					if r_sp_begin and not r_sp_end then
						r_sp_end = string.len(r_text) - c_bytes -- uzavřít skupinu mezer
					end
				end
			end

			if r_chars >= max_chars or b == 10 then
				-- dosažen maximální počet znaků nebo znak \n => uzavřít řádku
				if line_separator and #result > 0 then
					result[#result] = result[#result]..line_separator
				end
				if r_chars < max_chars or not r_sp_begin then
					-- žádné mezery => tvrdé dělení
					table.insert(result, r_text)
					r_text = ""
					r_chars = 0
					r_sp_begin, r_sp_end = nil, nil
				elseif not r_sp_end then
					-- průběžná skupina mezer => rozdělit zde
					table.insert(result, r_text:sub(1, r_sp_begin - 1))
					r_text = ""
					r_chars = 0
					r_sp_begin, r_sp_end = nil, nil
				else
					-- byla skupina mezer => rozdělit tam
					table.insert(result, r_text:sub(1, r_sp_begin - 1))
					r_text = r_text:sub(r_sp_end + 1, -1)
					r_chars = ch_core.utf8_length(r_text)
					r_sp_begin, r_sp_end = nil, nil
					if r_chars > 0 and b == 10 then
						i = i - c_bytes -- read this \n-byte again
					end
				end
				if max_result_lines and #result >= max_result_lines then
					return result -- skip reading other lines
				end
			end
			i = i + c_bytes
		else
			i = i + 1
		end
	end
	if r_chars > 0 then
		if line_separator and #result > 0 then
			result[#result] = result[#result]..line_separator
		end
		if r_sp_begin and not r_sp_end then
			-- průběžná skupina mezer
			table.insert(result, r_text:sub(1, r_sp_begin - 1))
		else
			table.insert(result, r_text)
		end
	end
	return result
end
function ch_core.utf8_radici_klic(s, store_to_cache)
	local result = utf8_sort_cache[s]
	if not result then
		local i = 1
		local l = s:len()
		local c, k
		result = {}
		while i <= l do
			c = s:sub(i, i)
			k = utf8_sort_data_1[c]
			if k then
				table.insert(result, k)
				i = i + 1
			else
				k = utf8_sort_data_2[s:sub(i, i + 1)]
				if k then
					table.insert(result, k)
					i = i + 2
				else
					k = utf8_sort_data_3[c]
					table.insert(result, k or c)
					i = i + 1
				end
			end
		end
		result = table.concat(result)
		if store_to_cache then
			utf8_sort_cache[s] = result
		end
	end
	return result
end

function ch_core.utf8_mensi_nez(a, b, store_to_cache)
	a = ch_core.utf8_radici_klic(a, store_to_cache)
	b = ch_core.utf8_radici_klic(b, store_to_cache)
	return a < b
end

-- == CH Formspec library == --

-- API:
-- ch_core.show_formspec(player_or_player_name, formname, formspec, formspec_callback, custom_state, options)
-- local function formspec_callback(custom_state, player, formname, fields)

--[[
	player_name => {
		callback = function,
		custom_state = ...,
		formname = string,
		object_id = int,
	}
]]
local formspec_states = {}
local formspec_states_next_id = 1

local function def_to_string(label, defitem, separator)
	if defitem == nil then
		return ""
	end
	local t = type(defitem)
	if t == "string" then
		return label.."["..defitem.."]"
	elseif t == "number" or t == "bool" then
		return label.."["..tostring(defitem).."]"
	elseif t == "table" then
		if #defitem == 0 then
			return label.."[]"
		else
			t = {}
			for i = 1, #defitem do
				t[i] = tostring(defitem[i])
			end
			t[1] = label.."["..t[1]
			t[#t] = t[#t].."]"
			return table.concat(t, separator)
		end
	else
		return ""
	end
end

--[[
	Sestaví záhlaví formspecu. Dovolené klíče jsou:
	-- formspec_version
	-- size
	-- position
	-- anchor
	-- padding
	-- no_prepend (bool)
	-- listcolors
	-- bgcolor
	-- background
	-- background9
	-- set_focus
	-- auto_background (speciální, vylučuje se s background a background9)
]]
function ch_core.formspec_header(def)
	local result, size_element

	if def.size ~= nil then
		if type(def.size) ~= "table" then
			error("def.size must be a table or nil!")
		end
		local s = def.size
		size_element = {"size["..tostring(s[1])}
		for i = 2, #s - 1, 1 do
			size_element[i] = tostring(s[i])
		end
		size_element[#s] = tostring(s[#s]).."]"
		size_element = table.concat(size_element, ",")
	else
		size_element = ""
	end

	result = {
		def_to_string("formspec_version", def.formspec_version, ""), -- 1
		size_element, -- 2
		def_to_string("position", def.position, ","), -- 3
		def_to_string("anchor", def.anchor, ","), -- 4
		def_to_string("padding", def.padding, ","), -- 5
		ifthenelse(def.no_prepend == true, "no_prepend[]", ""), -- 6
		def_to_string("listcolors", def.listcolors, ";"), -- 7
		def_to_string("bgcolor", def.bgcolor, ";"), -- 8
		def_to_string("background", def.background, ";"), -- 9
		def_to_string("background9", def.background9, ";"), -- 10
		def_to_string("set_focus", def.set_focus, ";"), -- 11
	}
	if not def.background and not def.background9 and def.formspec_version ~= nil and def.formspec_version > 1 then
		if def.auto_background == true then
			if result[7] == "" then
				-- colors according to Technic Chests:
				result[7] = "listcolors[#7b7b7b;#909090;#000000;#6e823c;#ffffff]"
			end
			--result[10] = "background9[0,0;1,1;ch_core_formspec_bg.png;true;16]"
			-- result[9] = "background[0,0;"..fsw..","..fsh..";ch_core_formspec_bg.png]"
		end
	end
	return table.concat(result)
end

--[[
	Má-li daná postava zobrazen daný formspec, uzavře ho a vrátí true.
	Jinak vrátí false.
	Je-li call_callback true, nastavený callback se před uzavřením zavolá
	s fields = {quit = "true"} a jeho návratová hodnota bude odignorována.
]]
function ch_core.close_formspec(player_name_or_player, formname, call_callback)
	if formname == nil or formname == "" then
		return false -- formname invalid
	end
	local p = ch_core.normalize_player(player_name_or_player)
	if p.player == nil then
		return false -- player invalid or not online
	end
	local formspec_state = formspec_states[p.player_name]
	if formspec_state == nil or formspec_state.formname ~= formname then
		return false -- formspec not open or the formname is different
	end
	if call_callback then
		formspec_state.callback(formspec_state.custom_state, p.player, formname, {quit = "true"})
	end
	minetest.close_formspec(p.player_name, formname)
	if formspec_states[p.player_name] ~= nil and formspec_states[p.player_name].object_id == formspec_state.object_id then
		formspec_states[p.player_name] = nil
	end
	return true
end

--[[
	Zobrazí hráči/ce formulář a nastaví callback pro jeho obsluhu.
	Callback nemusí být zavolán v nestandardních situacích jako
	v případě odpojení klienta.
]]
function ch_core.show_formspec(player_name_or_player, formname, formspec, callback, custom_state, options)
	local p = ch_core.normalize_player(player_name_or_player)
	if p.player == nil then return false end -- player invalid or not online

	if formname == nil or formname == "" then
		-- generate random formname
		formname = "ch_core:"..minetest.sha1(tostring(bit.bxor(minetest.get_us_time(), math.random(1, 1099511627775))), false)
	end

	local id = formspec_states_next_id
	formspec_states_next_id = id + 1
	formspec_states[p.player_name] = {
		callback = callback or function(...) return end,
		custom_state = custom_state,
		formname = formname,
		object_id = id,
	}

	minetest.show_formspec(p.player_name, formname, formspec)
	return formname
end

--[[
	Aktualizuje již zobrazený formspec. Vrátí true v případě úspěchu.
	formspec_or_function může být buď řetězec, nebo funkce, která bude
	pro získání řetězce zavolána s parametry: (player_name, formname, custom_state).
	Pokud nevrátí řetězec, update_formspec skončí a vrátí false.
]]
function ch_core.update_formspec(player_name_or_player, formname, formspec_or_function)
	if formname == nil or formname == "" then
		return false -- formname invalid
	end
	local p = ch_core.normalize_player(player_name_or_player)
	if p.player == nil then
		return false -- player invalid or not online
	end
	local formspec_state = formspec_states[p.player_name]
	if formspec_state == nil or formspec_state.formname ~= formname then
		return false -- formspec not open or the formname is different
	end
	local t = type(formspec_or_function)
	local formspec
	if t == "string" then
		formspec = formspec_or_function
	elseif t == "function" then
		formspec = formspec_or_function(p.player_name, formname, formspec_state.custom_state)
		if type(formspec) ~= "string" then
			return false
		end
	else
		return false -- invalid formspec argument
	end
	minetest.show_formspec(p.player_name, formname, formspec)
	return true
end

local function on_player_receive_fields(player, formname, fields)
	local player_name = assert(player:get_player_name())
	local formspec_state = formspec_states[player_name]
	if formspec_state == nil then
		return -- formspec not by ch_core
	end
	if formspec_state.formname ~= formname then
		minetest.log("warning", player_name..": received fields of form "..(formname or "nil").." when "..(formspec_state.formname or "nil").." was expected")
		formspec_states[player_name] = nil
		return
	end
	local result = formspec_state.callback(formspec_state.custom_state, player, formname, fields, {}) -- custom_state, player, formname, fields
	if type(result) == "string" then
	--        string => show as formspec
		formspec_states[player_name] = formspec_state
		minetest.show_formspec(player_name, formname, result)
	elseif fields ~= nil and fields.quit == "true" and formspec_states[player_name] ~= nil and formspec_states[player_name].object_id == formspec_state.object_id then
		formspec_states[player_name] = nil
	end
	return true
end
minetest.register_on_player_receive_fields(on_player_receive_fields)


-- set into place
advtrains.lines.ch_core = ch_core
