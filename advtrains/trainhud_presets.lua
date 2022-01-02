advtrains.hud.presets = {}

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
	ht[#ht+1] = sformat("10,10=(advtrains_hud_ars.png^[multiply\\:%s)", (not (advtrains.interlocking and train.ars_disable)) and "cyan" or "darkslategray")
	ht[#ht+1] = sformat("50,10=(advtrains_hud_lzb.png^[multiply\\:%s)", train.hud_lzb_effect_tmr and "red" or "darkslategray")
	ht[#ht+1] = sformat("90,10=(advtrains_hud_shunt.png^[multiply\\:%s)", train.is_shunt and "orange" or "darkslategray")
	ht[#ht+1] = sformat("145,10=(advtrains_hud_autocouple.png^[multiply\\:%s)", train.autocouple and "orange" or "darkslategray")
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
	ht[#ht+1] = sformat("100,45=(advtrains_hud_atc.png^[multiply\\:%s)", (train.tarvelocity or train.atc_command) and "cyan" or "darkslategray")
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

	ht[#ht+1] = sformat("151,5=(advtrains_hud_jp_forward.png^[multiply\\:%s)", flip and "darkslategray" or "orange")
	ht[#ht+1] = sformat("188,5=(advtrains_hud_jp_reverse.png^[multiply\\:%s)", flip and "orange" or "darkslategray")

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

	ht[#ht+1] = sformat("235,5=(advtrains_hud_jp_atc.png^[multiply\\:%s)", (train.tarvelocity or train.atc_command) and "orange" or "darkslategray")
	ht[#ht+1] = sformat("235,30=(advtrains_hud_jp_ars.png^[multiply\\:%s)", (not (advtrains.interlocking and train.ars_disable)) and "orange" or "darkslategray")
	ht[#ht+1] = sformat("235,55=(advtrains_hud_jp_lzb.png^[multiply\\:%s)", train.hud_lzb_effect_tmr and "orange" or "darkslategray")
	ht[#ht+1] = sformat("235,80=(advtrains_hud_jp_shunt.png^[multiply\\:%s)", train.is_shunt and "orange" or "darkslategray")
	ht[#ht+1] = sformat("235,105=(advtrains_hud_jp_autocouple.png^[multiply\\:%s)", train.autocouple and "orange" or "darkslategray")

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
