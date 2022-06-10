local sformat = string.format
local fsescape = minetest.formspec_escape

local function make_list(entries)
	local t = {}
	for k, v in ipairs(entries) do
		t[k] = fsescape(v)
	end
	return table.concat(t, ",")
end

local function f_button_exit(x, y, w, h, id, text)
	return sformat("button_exit[%f,%f;%f,%f;%s;%s]", x, y, w, h, id, text)
end

local function S_button_exit(x, y, w, h, id, ...)
	return f_button_exit(x, y, w, h, id, attrans(...))
end

local function f_dropdown(x, y, w, id, entries, sel, indexed)
	return sformat("dropdown[%f,%f;%f;%s;%s;%d%s]",
		x, y, w, id, make_list(entries),
		sel or 1,
		indexed and ";true" or "")
end

local function f_label(x, y, text)
	return sformat("label[%f,%f;%s]", x, y, fsescape(text))
end

local function S_label(x, y, ...)
	return f_label(x, y, attrans(...))
end

local function f_tabheader(x, y, w, h, id, entries, sel, transparent, border)
	local st = {string.format("%f,%f",x, y)}
	if h then
		if w then
			st[#st+1] = string.format("%f,%f", w, h)
		else
			st[#st+1] = tostring(h)
		end
	end
	st[#st+1] = tostring(id)
	st[#st+1] = make_list(entries)
	st[#st+1] = tostring(sel)
	if transparent ~= nil then
		st[#st+1] = tostring(transparent)
		if border ~= nil then
			st[#st+1] = tostring(border)
		end
	end
	return string.format("tabheader[%s]", table.concat(st, ";"))
end

return {
	button_exit = f_button_exit,
	S_button_exit = S_button_exit,
	dropdown = f_dropdown,
	label = f_label,
	S_label = S_label,
	tabheader = f_tabheader,
}
