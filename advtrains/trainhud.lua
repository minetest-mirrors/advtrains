--trainhud.lua: holds all the code for train controlling

advtrains.hud = {}
advtrains.hhud = {}

minetest.register_on_leaveplayer(function(player)
advtrains.hud[player:get_player_name()] = nil
advtrains.hhud[player:get_player_name()] = nil
end)

local mletter={[1]="F", [-1]="R", [0]="N"}

function advtrains.on_control_change(pc, train, flip)
   	local maxspeed = train.max_speed or 10
	if pc.sneak then
		if pc.up then
			train.tarvelocity = maxspeed
		end
		if pc.down then
			train.tarvelocity = 0
		end
		if pc.left then
			train.tarvelocity = 4
		end
		if pc.right then
			train.tarvelocity = 8
		end
		--[[if pc.jump then
			train.brake = true
			--0: released, 1: brake and pressed, 2: released and brake, 3: pressed and brake
			if not train.brake_hold_state or train.brake_hold_state==0 then
				train.brake_hold_state = 1
			elseif train.brake_hold_state==2 then
				train.brake_hold_state = 3
			end
		elseif train.brake_hold_state==1 then
			train.brake_hold_state = 2
		elseif train.brake_hold_state==3 then
			train.brake = false
			train.brake_hold_state = 0
		end]]
		--shift+use:see wagons.lua
	else
		local act=false
		if pc.jump then
			train.ctrl_user = 1
			act=true
		end
		-- If atc command set, only "Jump" key can clear command. To prevent accidental control.
		if train.tarvelocity or train.atc_command then
			return
		end
		if pc.up then
		   train.ctrl_user=4
		   act=true
		end
		if pc.down then
			if train.velocity>0 then
				if pc.jump then
					train.ctrl_user = 0
				else
					train.ctrl_user = 2
				end
				act=true
			else
				advtrains.invert_train(train.id)
				advtrains.atc.train_reset_command(train)
			end
		end
		if pc.left then
			if train.door_open ~= 0 then
				train.door_open = 0
			else
				train.door_open = -1
			end
		end
		if pc.right then
			if train.door_open ~= 0 then
				train.door_open = 0
			else
				train.door_open = 1
			end
		end
		if not act then
			train.ctrl_user = nil
		end
	end
end
function advtrains.update_driver_hud(pname, train, flip, thud, ghud)
	local inside=train.text_inside or ""
	local ft = (thud or advtrains.hud.dtext)(train, flip)
	local ht, gs = (ghud or advtrains.hud.dgraphical)(train, flip)
	advtrains.set_trainhud(pname, inside.."\n"..ft, ht, gs)
end
function advtrains.clear_driver_hud(pname)
	advtrains.set_trainhud(pname, "")
end

function advtrains.set_trainhud(name, text, driver, gs)
	gs = gs or 110
	local hud = advtrains.hud[name]
	local player=minetest.get_player_by_name(name)
	if not player then
	   return
	end
	local driverhud = {
		hud_elem_type = "image",
		name = "ADVTRAINS_DRIVER",
		position = {x=0.5, y=1},
		offset = {x=0,y=-170},
		text = driver or "",
		alignment = {x=0,y=-1},
		scale = {x=1,y=1},}
	if not hud then
		hud = {["driver"]={}}
		advtrains.hud[name] = hud
		hud.id = player:hud_add({
			hud_elem_type = "text",
			name = "ADVTRAINS",
			number = 0xFFFFFF,
			position = {x=0.5, y=1},
			offset = {x=0, y=-190-gs},
			text = text,
			scale = {x=200, y=60},
			alignment = {x=0, y=-1},
		})
		hud.oldText=text
		hud.driver = player:hud_add(driverhud)
	else
		if hud.oldText ~= text then
			player:hud_change(hud.id, "text", text)
			player:hud_change(hud.id, "offset", {x=0, y=-190-gs})
			hud.oldText=text
		end
		if hud.driver then
			player:hud_change(hud.driver, "text", driver or "")
		elseif driver then
			hud.driver = player:hud_add(driverhud)
		end
	end
end

function advtrains.set_help_hud(name, text)
	local hud = advtrains.hhud[name]
	local player=minetest.get_player_by_name(name)
	if not player then
	   return
	end
	if not hud then
		hud = {}
		advtrains.hhud[name] = hud
		hud.id = player:hud_add({
			hud_elem_type = "text",
			name = "ADVTRAINS_HELP",
			number = 0xFFFFFF,
			position = {x=1, y=0.3},
			offset = {x=0, y=0},
			text = text,
			scale = {x=200, y=60},
			alignment = {x=1, y=0},
		})
		hud.oldText=text
		return
	elseif hud.oldText ~= text then
		player:hud_change(hud.id, "text", text)
		hud.oldText=text
	end
end

--train.lever:
--Speed control lever in train, for new train control system.
--[[
Value	Disp	Control	Meaning
0		BB		S+Space	Emergency Brake
1		B		Space	Normal Brake
2		-		S		Roll
3		o		<none>	Stay at speed
4		+		W		Accelerate
]]

function advtrains.hud.texture_escape(str)
	return string.gsub(str, "[%[%()^:]", "\\%1")
end

function advtrains.hud.dtext(train, flip)
	local st = {}
	if train.debug then st = {train.debug} end

	st[#st+1] = attrans("Train ID: @1", train.id)
	
	if res and res == 0 then
		st[#st+1] = attrans("OVERRUN RED SIGNAL! Examine situation and reverse train to move again.")
	end
	
	if train.atc_command then
			st[#st+1] = string.format("ATC: %s%s", train.atc_delay and advtrains.abs_ceil(train.atc_delay).."s " or "", train.atc_command or "")
	end
	
	return table.concat(st, "\n")
end

function advtrains.hud.sevenseg(digit, x, y, w, h, m)
	local st = {}
	local sformat = string.format
	local f = "%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d"..(m and "^%s)" or ")")
	local segs = {
		{h, 0, w, h},
		{0, h, h, w},
		{w+h, h, h, w},
		{h, w+h, w, h},
		{0, w+2*h, h, w},
		{w+h, w+2*h, h, w},
		{h, 2*(w+h), w, h}}
	local trans = {
		[0] = {true, true, true, false, true, true, true},
		[1] = {false, false, true, false, false, true, false},
		[2] = {true, false, true, true, true, false, true},
		[3] = {true, false, true, true, false, true, true},
		[4] = {false, true, true, true, false, true, false},
		[5] = {true, true, false, true, false, true, true},
		[6] = {true, true, false, true, true, true, true},
		[7] = {true, false, true, false, false, true, false},
		[8] = {true, true, true, true, true, true, true},
		[9] = {true, true, true, true, false, true, true}}
	local ent = trans[digit or 10]
	if not ent then return end
	for i = 1, 7, 1 do
		if ent[i] then
			local s = segs[i]
			st[#st+1] = sformat(f, x+s[1], y+s[2], s[3], s[4], m)
		end
	end
	return table.concat(st,":")
end

function advtrains.hud.number(number, padding, x, y, w, h, margin, modifier)
	local st = {}
	local number = math.abs(math.floor(number))
	if not padding then
		if number == 0 then
			padding = 0
		else
			padding = math.floor(math.log10(number))
		end
	else
		padding = padding - 1
	end
	for i = padding, 0, -1 do
		st[#st+1] = advtrains.hud.sevenseg(math.floor(number/10^i)%10, x+(padding-i)*(w+2*h+margin), y, w, h, modifier)
	end
	return table.concat(st,":")
end

function advtrains.hud.leverof(train)
	if not train then return nil end
	local tlev=train.lever or 3
	if train.velocity==0 and not train.active_control then tlev=1 end
	if train.hud_lzb_effect_tmr then
		tlev=1
	end
	return tlev
end

function advtrains.hud.lever(lever, x, y, w1, w2, height)
	local sformat = string.format
	local hs = height/5
	local st = {
		sformat("%d,%d=(advtrains_hud_bg.png^[colorize\\:cyan^[resize\\:%dx%d)", x, y, w1, hs),
		sformat("%d,%d=(advtrains_hud_bg.png^[colorize\\:white^[resize\\:%dx%d)", x, y+hs, w1, hs),
		sformat("%d,%d=(advtrains_hud_bg.png^[colorize\\:orange^[resize\\:%dx%d)", x, y+hs*2, w1, hs*2),
		sformat("%d,%d=(advtrains_hud_bg.png^[colorize\\:red^[resize\\:%dx%d)", x, y+hs*4, w1, hs),
		sformat("%d,%d=(advtrains_hud_bg.png^[colorize\\:darkslategray^[resize\\:%dx%d)", x+(w2+w1)/2, y+(hs-w1)/2, w1, hs*4+2*w1),
		sformat("%d,%d=(advtrains_hud_bg.png^[colorize\\:gray^[resize\\:%dx%d)", x+w1, y+(4-lever)*hs, w2, hs),
	}
	return table.concat(st, ":")
end

function advtrains.hud.door(o, x, y, w, h, m)
	local sformat = string.format
	local dw = (w-m*2)/4
	local ww = w-(dw+m)*2
	local wh = h/2-m
	local st = {
		sformat("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d^[colorize\\:white)", x+dw+m, y, ww, h),
		sformat("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d)", x+dw+m*2, y+m, ww-2*m, wh),
		sformat("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d^[colorize\\:%s)", x, y, dw, h, o==-1 and "white" or "darkslategray"),
		sformat("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d)", x+m, y+m, dw-2*m, wh),
		sformat("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d^[colorize\\:%s)", x+w-dw, y, dw, h, o==1 and "white" or "darkslategray"),
		sformat("%d,%d=(advtrains_hud_bg.png^[resize\\:%dx%d)", x+w-dw+m, y+m, dw-2*m, wh),
	}
	return table.concat(st, ":")
end

function advtrains.hud.dgraphical(train, flip)
	if not train then return "" end
	local sformat = string.format -- this appears to be faster than (...):format
	local sevenseg = advtrains.hud.sevenseg
	
	local max = train.max_speed or 10
	local res = train.speed_restriction
	local vel = advtrains.abs_ceil(train.velocity)
	local vel_kmh=advtrains.abs_ceil(advtrains.ms_to_kmh(train.velocity))
	
	local ht = {"[combine:440x110:0,0=(advtrains_hud_bg.png^[resize\\:440x110)"}
	if train.debug then st = {train.debug} end
	
	ht[#ht+1] = advtrains.hud.lever(advtrains.hud.leverof(train), 275, 10, 5, 30, 90)
	-- reverser
	ht[#ht+1] = sformat("245,10=(advtrains_hud_arrow.png^[transformFY%s)", flip and "" or "^[multiply\\:cyan")
	ht[#ht+1] = sformat("245,85=(advtrains_hud_arrow.png%s)", flip and "^[multiply\\:orange" or "")
	ht[#ht+1] = "250,35=(advtrains_hud_bg.png^[colorize\\:darkslategray^[resize\\:5x40)"
	ht[#ht+1] = sformat("240,%s=(advtrains_hud_bg.png^[resize\\:25x15^[colorize\\:gray)", flip and 65 or 30)
	-- train control/safety indication
	if train.tarvelocity or train.atc_command then
		ht[#ht+1] = "10,10=(advtrains_hud_atc.png^[multiply\\:cyan)"
	end
	if train.hud_lzb_effect_tmr then
		ht[#ht+1] = "45,10=(advtrains_hud_lzb.png^[multiply\\:red)"
	end
	if train.is_shunt then
		ht[#ht+1] = "80,10=(advtrains_hud_shunt.png^[multiply\\:orange)"
	end
	ht[#ht+1] = advtrains.hud.door(train.door_open, 165, 10, 60, 30, 2)
	-- speed indications
	ht[#ht+1] = advtrains.hud.number(vel, 2, 320, 10, 30, 10, 10, "[colorize\\:red\\:255")
	for i = 1, vel, 1 do
		ht[#ht+1] = sformat("%d,65=(advtrains_hud_bg.png^[resize\\:8x20^[colorize\\:white)", i*11-1)
	end
	for i = max+1, 20, 1 do
		ht[#ht+1] = sformat("%d,65=(advtrains_hud_bg.png^[resize\\:8x20^[colorize\\:darkslategray)", i*11-1)
	end
	if res and res > 0 then
		ht[#ht+1] = sformat("%d,60=(advtrains_hud_bg.png^[resize\\:3x30^[colorize\\:red\\:255)", 7+res*11)
	end
	if train.tarvelocity then
		ht[#ht+1] = sformat("%d,85=(advtrains_hud_arrow.png^[multiply\\:cyan^[transformFY^[makealpha\\:#000000)", 1+train.tarvelocity*11)
	end
	local lzb = train.lzb
	if lzb and lzb.checkpoints then
		local oc = lzb.checkpoints
		for i = 1, #oc do
			local spd = oc[i].speed
			spd = advtrains.speed.min(spd, train.speed_restriction)
			if spd == -1 then spd = nil end
			local c = not spd and "lime" or (type(spd) == "number" and (spd == 0) and "red" or "orange") or nil
			if c then
				ht[#ht+1] = sformat("130,10=(advtrains_hud_bg.png^[resize\\:30x5^[colorize\\:%s)",c)
				ht[#ht+1] = sformat("130,35=(advtrains_hud_bg.png^[resize\\:30x5^[colorize\\:%s)",c)
				if spd and spd~=0 then
					ht[#ht+1] = sformat("%d,50=(advtrains_hud_arrow.png^[multiply\\:red^[makealpha\\:#000000)", 1+spd*11) 
				end
				local floor = math.floor
				local dist = floor(((oc[i].index or train.index)-train.index))
				dist = math.max(0, math.min(999, dist))
				ht[#ht+1] = advtrains.hud.number(dist, 3, 130, 18, 4, 2, 3, "[colorize\\:"..c)
				break
			end
		end
	end
	
	return table.concat(ht,":"), 110
end

local texture = advtrains.hud.dgraphical { -- dummy train object to demonstrate the train hud
	max_speed = 15, speed_restriction = 15, velocity = 15, tarvelocity = 12,
	active_control = true, lever = 3, ctrl = {lzb = true}, is_shunt = true,
	door_open = 1, lzb = {checkpoints = {{speed=6, index=125.7}}}, index = 0,
	hud_lzb_effect_tmr = true,
}

minetest.register_node("advtrains:hud_demo",{
	description = "Train HUD demonstration",
	tiles = {texture},
	groups = {cracky = 3, not_in_creative_inventory = 1}
})

minetest.register_craft {
	output = "advtrains:hud_demo",
	recipe = {
		{"default:paper", "default:paper", "default:paper"},
		{"default:paper", "advtrains:trackworker", "default:paper"},
		{"default:paper", "default:paper", "default:paper"},
	}
}
