advtrains.hud.presets = {}

local sformat = string.format

local default_renderers = {}
for _, width in pairs {30,45,82} do
	for _, color in pairs {"cyan", "darkslategray", "orange", "red"} do
		default_renderers[color .. width] = advtrains.font.renderer{width = width, height = 30, bgcolor = color}
	end
end
local default_indicators = {
	ars = {"ARS", 10, 10, [true] = "darkslategray30", [false] = "cyan30"},
	atc = {"ATC", 100, 45, [true] = "cyan30", [false] = "darkslategray30"},
	lzb = {"LZB", 50, 10, [true] = "red30", [false] = "darkslategray30"},
	shunt = {"Shunt", 90, 10, [true] = "orange45", [false] = "darkslategray45"},
	autocouple = {"Autocouple", 145, 10, [true] = "orange82", [false] = "darkslategray82"}
}
local function make_indicators(renderers, indicators)
	for _, t in pairs(indicators) do
		local text, x, y = unpack(t)
		t[1], t[2], t[3] = nil
		for k, v in pairs(t) do
			t[k] = sformat("%d,%d=%s", x, y, advtrains.hud.texture_escape(renderers[v](text)))
		end
	end
	return indicators
end
default_indicators = make_indicators(default_renderers, default_indicators)
function advtrains.hud.presets.default(train, flip)
	if not train then return "" end
	local sformat = string.format -- this appears to be faster than (...):format
	
	local max = train.max_speed or 10
	local vel = advtrains.abs_ceil(train.velocity)
	local res = train.speed_restriction
	local tar = train.tarvelocity
	
	local ht = {"[combine:450x120:0,0=(advtrains_hud_bg.png^[resize\\:450x120)"}
	if train.debug then st = {train.debug} end
	
	ht[#ht+1] = advtrains.hud.lever(advtrains.hud.leverof(train), 275, 10, 5, 30, 100)
	-- reverser
	ht[#ht+1] = sformat("245,10=(advtrains_hud_arrow.png^[transformFY%s)", flip and "" or "^[multiply\\:cyan")
	ht[#ht+1] = sformat("245,95=(advtrains_hud_arrow.png%s)", flip and "^[multiply\\:orange" or "")
	ht[#ht+1] = "250,35=(advtrains_hud_bg.png^[colorize\\:darkslategray^[resize\\:5x50)"
	ht[#ht+1] = sformat("240,%s=(advtrains_hud_bg.png^[resize\\:25x15^[colorize\\:gray)", flip and 75 or 30)
	-- first row
	ht[#ht+1] = default_indicators.ars[advtrains.interlocking and ars_disable or false]
	ht[#ht+1] = default_indicators.lzb[train.hud_lzb_effect_tmr and true or false]
	ht[#ht+1] = default_indicators.shunt[train.is_shunt or false]
	ht[#ht+1] = default_indicators.autocouple[train.autocouple or false]
	-- second row
	local asp, dist = advtrains.hud.getlzb(train)
	if dist then
		local color
		if asp >= 0 then
			color = (asp > 0) and "orange" or "red"
			ht[#ht+1] = advtrains.hud.number(asp, 2, 10, 45, 5, 2, 2, color, "darkslategray")
			ht[#ht+1] = sformat("10,67=(advtrains_hud_ms.png^[multiply\\:%s)", color)
		else
			color = "lime"
			ht[#ht+1] = advtrains.hud.number(88, 2, 10, 45, 5, 2, 2, "darkslategray")
			ht[#ht+1] = "10,67=(advtrains_hud_ms.png^[multiply\\:darkslategray)"
		end
		ht[#ht+1] = advtrains.hud.number(dist, 3, 35, 45, 9, 4, 2, color, "darkslategray")
	else
		ht[#ht+1] = advtrains.hud.number(88, 2, 10, 45, 5, 2, 2, "darkslategray")
		ht[#ht+1] = "10,67=(advtrains_hud_ms.png^[multiply\\:darkslategray)"
		ht[#ht+1] = advtrains.hud.number(888, 3, 35, 45, 9, 4, 2, "darkslategray")
	end
	ht[#ht+1] = default_indicators.atc[(train.tarvelocity or train.atc_command) and true or false]
	if tar and tar >= 0 then
		local tc = math.min(max, tar)
		ht[#ht+1] = advtrains.hud.number(tar, 2, 135, 45, 5, 2, 2, "cyan", "darkslategray")
		ht[#ht+1] = "135,67=(advtrains_hud_ms.png^[multiply\\:cyan)"
	else
		ht[#ht+1] = advtrains.hud.number(88, 2, 135, 45, 5, 2, 2, "darkslategray")
		ht[#ht+1] = "135,67=(advtrains_hud_ms.png^[multiply\\:darkslategray)"
	end
	ht[#ht+1] = advtrains.hud.door(train.door_open, 167, 45, 60, 30, 2)
	-- speed indications
	ht[#ht+1] = advtrains.hud.number(vel, 2, 320, 10, 35, 10, 10, "red")
	ht[#ht+1] = advtrains.hud.speed_horizontal(train, 10, 80, 217, 30, 3)
	
	return table.concat(ht,":"), 120
end

local japan_renderers = {}
for _, color in pairs{"orange", "darkslategray"} do
	for _, length in pairs{52, 100} do
		japan_renderers[color .. length] = advtrains.font.renderer{width = length, height = 20, minwidth = length-4, textcolor = color}
	end
	for name, align in pairs{["37l"] = 0, ["37r"] = 1} do
		japan_renderers[color .. name] = advtrains.font.renderer{x = 2, width = 33, height = 20, halign = align, textcolor = color}
	end
end
local japan_indicators = {
	atc = {"自動", 235, 5, [true] = "orange52", [false] = "darkslategray52"},
	ars = {"自動路線設定", 235, 30, [true] = "darkslategray100", [false] = "orange100"},
	lzb = {"ＬＺＢ制限", 235, 55, [true] = "orange100", [false] = "darkslategray100"},
	shunt = {"入換", 235, 80, [true] = "orange100", [false] = "darkslategray100"},
	autocouple = {"自動連結", 235, 105, [true] = "orange100", [false] = "darkslategray100"},
	forward = {"前", 151, 5, [true] = "darkslategray37l", [false] = "orange37l"},
	reverse = {"後", 188, 5, [true] = "orange37r", [false] = "darkslategray37r"},
}
japan_indicators = make_indicators(japan_renderers, japan_indicators)
function advtrains.hud.presets.japan(train, flip)
	if not train then return "" end
	local sformat = string.format -- this appears to be faster than (...):format
	
	local max = train.max_speed or 10
	local vel = advtrains.abs_ceil(train.velocity)
	local res = train.speed_restriction
	local tar = train.tarvelocity
	
	local ht = {"[combine:340x130:0,0=(advtrains_hud_bg.png^[resize\\:340x130)"}

	ht[#ht+1] = advtrains.hud.number(vel, 2, 5, 5, 30, 10, 10, "red")
	ht[#ht+1] = advtrains.hud.speed_horizontal(train, 5, 100, 217, 25, 3)
	ht[#ht+1] = advtrains.hud.lever(advtrains.hud.leverof(train), 122, 5, 3, 20, 90)

	ht[#ht+1] = japan_indicators.forward[flip or false]
	ht[#ht+1] = japan_indicators.reverse[flip or false]

	ht[#ht+1] = advtrains.hud.door(train.door_open, 151, 30, 72, 39, 2)

	local asp, dist = advtrains.hud.getlzb(train)
	if dist then
		local color
		if asp >= 0 then
			color = (asp > 0) and "orange" or "red"
			ht[#ht+1] = advtrains.hud.number(asp, 2, 151, 74, 5, 2, 2, color, "darkslategray")
			ht[#ht+1] = sformat("151,92=(advtrains_hud_ms.png^[multiply\\:%s)", color)
		else
			color = "lime"
			ht[#ht+1] = advtrains.hud.number(88, 2, 151, 74, 5, 2, 2, "darkslategray")
			ht[#ht+1] = "151,92=(advtrains_hud_ms.png^[multiply\\:darkslategray)"
		end
		ht[#ht+1] = advtrains.hud.number(dist, 3, 177, 74, 10, 2, 2, color, "darkslategray")
	else
		ht[#ht+1] = advtrains.hud.number(88, 2, 151, 74, 5, 2, 2, "darkslategray")
		ht[#ht+1] = "151,92=(advtrains_hud_ms.png^[multiply\\:darkslategray)"
		ht[#ht+1] = advtrains.hud.number(888, 3, 177, 74, 10, 2, 2, "darkslategray")
	end

	ht[#ht+1] = japan_indicators.atc[(train.tarvelocity or train.atc_command) and true or false]
	ht[#ht+1] = japan_indicators.ars[advtrains.interlocking and train.ars_disable or false]
	ht[#ht+1] = japan_indicators.lzb[train.hud_lzb_effect_tmr and true or false]
	ht[#ht+1] = japan_indicators.shunt[train.is_shunt or false]
	ht[#ht+1] = japan_indicators.autocouple[train.autocouple or false]

	if tar and tar >= 0 then
		local tc = math.min(max, tar)
		ht[#ht+1] = advtrains.hud.number(tar, 2, 288, 7, 5, 2, 2, "orange", "darkslategray")
		ht[#ht+1] = "310,15=(advtrains_hud_ms.png^[multiply\\:orange)"
	else
		ht[#ht+1] = advtrains.hud.number(88, 2, 288, 7, 5, 2, 2, "darkslategray")
		ht[#ht+1] = "310,15=(advtrains_hud_ms.png^[multiply\\:darkslategray)"
	end
	
	return table.concat(ht,":"), 130
end

--advtrains.hud.presets.default = advtrains.hud.presets.japan
