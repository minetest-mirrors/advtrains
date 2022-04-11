local sformat = string.format
local fsescape = minetest.formspec_escape

local function f_button_exit(x, y, w, h, id, text)
	return sformat("button_exit[%f,%f;%f,%f;%s;%s]", x, y, w, h, id, text)
end

local function S_button_exit(x, y, w, h, id, ...)
	return f_button_exit(x, y, w, h, id, attrans(...))
end

local function f_dropdown(x, y, w, id, entries, sel, indexed)
	local t = {}
	for k, v in pairs(entries) do
		t[k] = fsescape(v)
	end
	return sformat("dropdown[%f,%f;%f;%s;%s;%d%s]",
		x, y, w, id, table.concat(t, ","),
		sel or 1,
		indexed and ";true" or "")
end

local function f_label(x, y, text)
	return sformat("label[%f,%f;%s]", x, y, fsescape(text))
end

local function S_label(x, y, ...)
	return f_label(x, y, attrans(...))
end

return {
	button_exit = f_button_exit,
	S_button_exit = S_button_exit,
	dropdown = f_dropdown,
	label = f_label,
	S_label = S_label,
}
