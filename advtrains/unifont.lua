--[[
Note on copyright:
The Unifont website (http://unifoundry.com/unifont/index.html) says that
the font files are licensed "under the GNU General Public License,
either version 2 or (at your option) a later version". Section 13 of the
GNU GPLv3 gives the "permission to link or combine any covered work with
a work licensed under version 3 of the GNU Affero General Public License
into a single combined work". The use of Unifont here should fall under
this case considering that
- Unifont is licensed under GNU GPLv2+, and, in this case, the terms of
the GNU GPLv3 is used here
- We are combining Unifont into advtrains, and the latter is licensed
under the GNU AGPLv3.
However, as I am not a lawyer, I can not be sure whether this
interpretation is legally accepted.
- Y.W.
]]

local tonumber, unpack = tonumber, unpack
local sbyte, schar, sformat, smatch, ssub = string.byte, string.char, string.format, string.match, string.sub
local tconcat = table.concat

local texture_dir = tconcat({advtrains.modpath, "textures", "unifont"}, DIR_DELIM)
minetest.mkdir(texture_dir)
local function texture_file(cp)
	return sformat(cp < 65536 and "%s_%04x.bmp" or "%s_%06x.bmp", "advtrains_unifont", cp)
end
local function texture_path(cp)
	return texture_dir .. DIR_DELIM .. texture_file(cp)
end


local cpwidth = {}

local function mbstocps(str)
	local t = {}
	local i = 1
	while i <= #str do
		local c = sbyte(str, i)
		local bt = {}
		i = i+1
		if c < 128 then
			-- nop
		elseif c < 192 then
			c = 0
		elseif c < 224 then
			bt = {sbyte(str, i, i)}
		elseif c < 240 then
			bt = {sbyte(str, i, i+1)}
		elseif c < 248 then
			bt = {sbyte(str, i, i+2)}
		else
			c = 0
		end
		for i = 1, #bt do
			c = c*64+(bt[i]%64)
		end
		i = i + #bt
		t[#t+1] = c
	end
	return t
end

local function renderer(opts)
	local opts = opts or {}
	local x0, y0 = (opts.x or 0), (opts.y or 0)
	local width, height = opts.width, opts.height
	local halign, valign = (opts.halign or 0.5), (opts.valign or 0.5)
	local textcolor = opts.textcolor or "black"
	local bgcolor = opts.bgcolor
	local function break_lines(cps)
		local lastline = {width = 0}
		local lines = {lastline}
		local i = 1
		while i <= #cps do
			local char = cps[i]
			if char == 10 then
				lastline = {width = 0}
				lines[#lines+1] = lastline
			elseif cpwidth[char] then
				lastline.width = lastline.width + cpwidth[char]
				lastline[#lastline+1] = char
			end
			i = i+1
		end
		return lines
	end
	return function(str)
		local lines = break_lines(mbstocps(str))
		local textheight = 16*#lines
		local y = y0 + (height-textheight)*valign
		local st = {
			"[combine",
			sformat("%dx%d", x0+width, y0+height)
		}
		for i = 1, #lines do
			local line = lines[i]
			local x = x0 + (width - line.width)*halign
			for j = 1, #line do
				local cp = line[j]
				st[#st+1] = sformat("%d,%d=%s", x, y, texture_file(cp))
				x = x + cpwidth[cp]
			end
		end
		local prefix = ""
		if bgcolor then
			prefix = sformat("[combine:%dx%d:%d,%d=\\(advtrains_hud_bg.png\\^[resize\\:%dx%d\\^[colorize\\:%s\\:alpha\\)^",
				x0+width, y0+height, x0, y0, width, height, bgcolor)
		end
		return sformat("(%s(%s^[makealpha:000000^[multiply:%s))", prefix, tconcat(st, ":"), textcolor)
	end
end

local function render(str, opts)
	return renderer(opts)(str)
end

-- Generate texture files
local bmp_headers = {}
for _, v in pairs {8, 16} do
	bmp_headers[v] = tconcat{
		"BM", -- starting bytes
		"\125\0\0\0", -- file size
		"\0\0\0\0", -- reserved fields
		"\62\0\0\0", -- offset of the pixel array
		"\40\0\0\0", -- BITMAPINFOHEADER
		schar(v, 0, 0, 0), -- image width
		"\16\0\0\0", -- image height
		"\1\0", -- number of color planes (must be 1, apparently)
		"\1\0", -- bits per pixel
		"\0\0\0\0", -- no compression
		"\64\0\0\0", -- size of the raw bitmap data
		"\0\0\0\0\0\0\0\0", -- image resolution (irrelevant here)
		"\2\0\0\0", -- number of colors in the palette
		"\0\0\0\0", -- "important" colors
		-- palette
		"\0\0\0\0",
		"\255\255\255\0",
	}
end

local t0 = os.clock()
local f = io.open(advtrains.modpath .. DIR_DELIM .. "unifont.hex", "rb") or error("Cannot open unifont.hex")
for l in f:lines() do
	local cp, raw = smatch(l, "^(%x+):(%x+)$")
	local cp = tonumber(cp, 16) or error("Cannot parse codepoint from " .. cp)
	local rowsize = #raw/16
	local width = rowsize*4
	cpwidth[cp] = width
	local rowbytes = rowsize/2
	local bytes = {bmp_headers[width]}
	for i = 0, 15 do
		local row = {}
		local offset = i*rowsize
		for j = 1, rowbytes do
			local offset = offset+2*j-1
			local data = ssub(raw, offset, offset+1)
			row[j] = tonumber(data, 16)
		end
		for j = rowbytes+1, 4 do
			row[j] = 0
		end
		bytes[17-i] = schar(unpack(row))
	end
	minetest.safe_file_write(texture_path(cp), tconcat(bytes))
end
minetest.log("action",sformat("[advtrains/unifont] Generated textures in %f seconds", os.clock()-t0))

return {
	texture_dir = texture_dir,
	renderer = renderer,
	render = render
}
