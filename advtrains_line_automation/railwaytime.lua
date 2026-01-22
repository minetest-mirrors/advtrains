-- railwaytime.lua
-- Advtrains uses a desynchronized time for train movement. Everything is counted relative to this time counter.
-- The advtrains-internal time is in no way synchronized to the real-life time, due to:
-- - Lag
-- - Server stops/restarts
-- However, this means that implementing a "timetable" system using the "real time" is not practical. Therefore,
-- we introduce a custom time system, the RWT(Railway Time), which has nothing to do with RLT(Real-Life Time)
-- RWT has a time cycle of 1 day. This should be sufficient for most train lines that will ever be built in Minetest.
-- A RWT looks like this:    14;37;25
-- The ; is to distinguish it from a normal RLT (which has colons e.g. 12:34:56). Left number is hours, middle number is minutes, right number is seconds.
-- The minimum RWT is 00;00;00, the maximum is 23;59;59.
-- There is an "adapt mode", which was proposed by gpcf, and results in RWT automatically adapting itself to real-world time.
-- It works by shifting the hour/minute/second after the realtime hour/minute/second, adjusting the cycle value as needed.
--[[
There is an important distinction between:

## Time (absolute time) ##
Represents a time instant.
It is identified by the 4 values cycle (day), hour, minute and second. These values are never negative.

In string form, it is written as C;HH;MM;SS.
The following short forms are allowed to display a RWT (but they do not uniquely identify a RWT):
HH;MM;SS
HH;MM
It is discouraged to use the string form to store RWTs, the table form or seconds form is better.

In table form:
{ s=45, m=23, h=12, c=1 }

In seconds form:
c*24*60*60 + h*60*60 + m*60 + s

Absolute time wraps around at a boundary of 7 cycles (valid cycle values are 0 to 6). If the difference between instants A and B
is < 3.5 days, B is considered in the future, otherwise B is considered in the past.
The RWT functions take this wrapping into account.

## Interval (relative time) ##
Represents a difference between times.

It is commonly represented in seconds form as a number of seconds.
It can be formatted as a string e.g.
 90 seconds = "+01;30"
-90 seconds = "-01;30"
When converting to a string, a + or - must be prepended.
When parsing a string it is permissible to leave out the + if it is clear from the context that
an interval is parsed.
The meaning of string short forms differ from the time instant case:
[+-]MM;SS (meaning when interval is parsed FROM a string, and the default when converting to string and HH==0 and C==0)
[+-]HH;MM;SS (when HH!=0 and C==0)
[+-]C;HH;MM;SS (when all !=0)
[+-]HH;MM (permissible only when converting TO a string, to be used when it is displayed alongside an instant e.g. 05;30+00;04)


]]--


local rwt = {}

local CYCLE = 24*60*60
local MODULUS = CYCLE*7
local MODULUS_H = MODULUS / 2

-- adjust so that it is in range [-MODULUS/2, MODULUS/2)
local function i_adjust(sec)
	return ((sec + MODULUS_H) % MODULUS) - MODULUS_H
end

--Time Stamp (Seconds since start of world)
local e_time = 0
local e_has_loaded = false

local setting_rwt_real = minetest.settings:get("advtrains_lines_rwt_realtime")
if setting_rwt_real=="" then
	setting_rwt_real = "independent"
end

local e_last_epoch -- last real-time timestamp

-- Advance RWT to match minute/second to the current real-world time
-- only accounts for the minute/second part, leaves hour/cycle untouched
local function adapt_real_time()
	local datetab = os.date("*t")
	local real_sectotal = 60*datetab.min + datetab.sec
	
	local rwttab = rwt.now()
	local rwt_sectotal = 60*rwttab.m + rwttab.s
	
	--calculate the difference and take it %3600 (seconds/hour) to always move forward
	local secsfwd = (real_sectotal - rwt_sectotal) % 3600
	
	atlog("[lines][rwt] Skipping",secsfwd,"seconds forward to sync rwt (",rwt.to_string(rwttab),") to real time (",os.date("%H:%M:%S"),")")
	
	e_time = (e_time + secsfwd) % MODULUS
end

function rwt.set_time(t)
	e_time = t or 0
	if setting_rwt_real == "adapt_real" then
		adapt_real_time()
	end
	atlog("[lines][rwt] Initialized railway time: ",rwt.to_string(e_time))
	e_last_epoch = os.time()
	
	e_has_loaded = true
end

function rwt.get_time()
	return e_time
end

function rwt.step(dt)
	if not e_has_loaded then
		rwt.set_time(0)
	end

	if setting_rwt_real=="independent" then
		-- Regular stepping with dtime
		e_time = (e_time + dt) % MODULUS
	else
		-- advance with real-world time
		local diff = os.time() - e_last_epoch
		e_last_epoch = os.time()
		
		if diff>0 then
			e_time = (e_time + diff) % MODULUS
		end
	end
end

function rwt.now()
	return rwt.to_table(e_time)
end

function rwt.new_t(c, h, m, s)
	assert(c>=0 and c<7 and c==math.floor(c))
	assert(h>=0 and h<24 and h==math.floor(h))
	assert(m>=0 and m<60 and m==math.floor(m))
	assert(s>=0 and s<60)
	return {
		c = c or 0,
		h = h or 0,
		m = m or 0,
		s = s or 0
	}
end

function rwt.new_i(sign, c, h, m, s)
	assert(math.abs(sign)==1)
	assert(c>=0 and c<7 and c==math.floor(c))
	assert(h>=0 and h<24 and h==math.floor(h))
	assert(m>=0 and m<60 and m==math.floor(m))
	assert(s>=0 and s<60)
	
	return sign * (c*24*60*60 + h*60*60 + m*60 + s)
end


function rwt.copy(rwtime)
	local rwtimet = rwt.to_table(rwtime)
	return {
		c = rwtimet.c or 0,
		h = rwtimet.h or 0,
		m = rwtimet.m or 0,
		s = rwtimet.s or 0
	}
end

function rwt.to_table(rwtime)
	if type(rwtime) == "table" then
		return rwtime
	elseif type(rwtime) == "string" then
		return rwt.parse_t(rwtime)
	elseif type(rwtime) == "number" then
		local res = {}
		local seconds = atfloor(rwtime)
		res.s = seconds % 60
		local minutes = atfloor(seconds/60)
		res.m = minutes % 60
		local hours = atfloor(minutes/60)
		res.h = hours % 24
		res.c = atfloor(hours/24)
		return res
	end
end

local function intv_to_table(rwintp)
	if type(rwintp) == "number" then
		local res = {}
		local rwint = math.abs(rwintp)
		if rwint~=0 then
			res.sign = rwintp/rwint -- 1 or -1
		else
			res.sign = 1
		end
		local seconds = atfloor(rwint)
		res.s = seconds % 60
		local minutes = atfloor(seconds/60)
		res.m = minutes % 60
		local hours = atfloor(minutes/60)
		res.h = hours % 24
		res.c = atfloor(hours/24)
		return res
	else
		error("intv_to_table needs number")
	end
end

-- time instant to seconds
function rwt.t_sec(rwtime)
	local res = rwtime
	if type(rwtime) == "string" then
		res = rwt.parse_t(rwtime)
	elseif type(rwtime) == "number" then
		return rwtime
	end
	if type(res)=="table" then
		return res.c*60*60*24 + res.h*60*60 + res.m*60 + res.s
	end
end

-- interval to seconds
function rwt.i_sec(rwint)
	if type(rwint) == "string" then
		return rwt.parse_i(rwint)
	elseif type(rwint) == "number" then
		return rwint
	elseif type(rwint)=="table" then
		return res.sign * (res.c*60*60*24 + res.h*60*60 + res.m*60 + res.s)
	end
end

-- time to string
-- fmt:
-- 0, nil or false: full format C;HH;MM;SS
-- 1 or true: format HH;MM;SS
-- 2: format MM;SS
-- 3: format HH;MM
function rwt.t_str(rwtime_p, fmt)
	local rwtime = rwt.to_table(rwtime_p)
	if fmt==0 or not fmt then
		return string.format("%d;%02d;%02d;%02d", rwtime.c, rwtime.h, rwtime.m, rwtime.s)
	elseif fmt==1 or fmt==true then
		return string.format("%02d;%02d;%02d", rwtime.h, rwtime.m, rwtime.s)
	elseif fmt==2 then
		return string.format("%02d;%02d", rwtime.m, rwtime.s)
	elseif fmt==3 then
		return string.format("%02d;%02d", rwtime.h, rwtime.m)
	end
end
-- compatibility alias
rwt.to_string = rwt.t_str

-- interval to string
function rwt.i_str(rwint_p, omit_plus, omit_second)
	local rwint = intv_to_table(rwint_p)
	-- sign
	local sic = rwint.sign==1 and (omit_plus and "" or "+") or "-"
	-- find out formatting
	if omit_second then
		if rwint.c~=0 then
			return string.format("%s%d;%02d;%02d", sic, rwint.c, rwint.h, rwint.m)
		else
			return string.format("%s%02d;%02d", sic, rwint.h, rwint.m)
		end
	else
		if rwint.c~=0 then
			return string.format("%s%d;%02d;%02d;%02d", sic, rwint.c, rwint.h, rwint.m, rwint.s)
		elseif rwint.h~=0 then
			return string.format("%s%02d;%02d;%02d", sic, rwint.h, rwint.m, rwint.s)
		else
			return string.format("%s%02d;%02d", sic, rwint.m, rwint.s)
		end
	end
end

---

local function v_n(str)
	if str == "" then
		return 0
	end
	return tonumber(str)
end

-- parse an interval (the default case - parsing an instant is rare)
function rwt.parse(str)
	--atdebug("parse",str)
	--4-value form
	local sic, str_c, str_h, str_m, str_s = string.match(str, "^([%-%+]?)(%d?%d?);(%d%d);(%d%d);(%d?%d?)$")
	if sic and str_c and str_h and str_m and str_s then
		--atdebug("4v", sic, str_c, str_h, str_m, str_s)
		local c, h, m, s = v_n(str_c), v_n(str_h), v_n(str_m), v_n(str_s)
		if c and h and m and s then
			return rwt.new_i(sic=="-" and -1 or 1, c,h,m,s)
		end
	end
	--3-value form
	local sic, str_h, str_m, str_s = string.match(str, "^([%-%+]?)(%d?%d?);(%d%d);(%d?%d?)$")
	if sic and str_h and str_m and str_s then
		--atdebug("3v", sic, str_h, str_m, str_s)
		local c, h, m, s = 0, v_n(str_h), v_n(str_m), v_n(str_s)
		if c and h and m and s then
			return rwt.new_i(sic=="-" and -1 or 1, c,h,m,s)
		end
	end
	--2-value form
	local sic, str_m, str_s = string.match(str, "^([%-%+]?)(%d?%d?);(%d?%d?)$")
	if sic and str_m and str_s then
		--atdebug("2v", sic, str_m, str_s)
		local c, h, m, s = 0, 0, v_n(str_m), v_n(str_s)
		if c and h and m and s then
			return rwt.new_i(sic=="-" and -1 or 1, c,h,m,s)
		end
	end
end
rwt.parse_i = rwt.parse

-- parse a time instant - only the 4-value form is allowed!
function rwt.parse_t(str)
	--atdebug("parse",str)
	--4-value form
	local str_c, str_h, str_m, str_s = string.match(str, "^(%d?%d?);(%d%d);(%d%d);(%d?%d?)$")
	if str_c and str_h and str_m and str_s then
		--atdebug("4v", str_c, str_h, str_m, str_s)
		local c, h, m, s = v_n(str_c), v_n(str_h), v_n(str_m), v_n(str_s)
		if c and h and m and s then
			return rwt.new_t(c,h,m,s)
		end
	end
end

---

-- add a time and an interval. The result is a time (table form)
function rwt.add(t1, i)
	local t1s = rwt.t_sec(t1)
	local t2s = rwt.i_sec(i)
	return rwt.to_table( (t1s + t2s) % MODULUS )
end

-- subtract a time and an interval. The result is a time (table form)
function rwt.sub(t1, i)
	local t1s = rwt.t_sec(t1)
	local t2s = rwt.i_sec(i)
	return rwt.to_table( (t1s - t2s) % MODULUS )
end


-- How many seconds FROM t1 TO t2 (two time instants, result is an interval)
function rwt.diff(t1, t2)
	local t1s = rwt.t_sec(t1)
	local t2s = rwt.t_sec(t2)
	return i_adjust(t2s - t1s)
end

-- Whether t1 is (strictly) after t2
function rwt.is_after(t1, t2)
	return rwt.diff(t2,t1) > 0
end

-- Whether t1 is (strictly) before t2
function rwt.is_before(t1, t2)
	return rwt.diff(t1,t2) > 0
end

-- Helper functions for handling "repeating times" (rpt)
-- Those are generic declarations for time intervals like "every 5 minutes", with an optional offset
-- Note the following:
-- - rwtime is a time instant, rpt_interval and rpt_offset are intervals
-- - repeating times are hard-capped at cycle (24-hour) boundary
-- - if rpt_interval is given as nil, there is exactly 1 match per cycle and it is at X;00;00;00 + offset ( equals a time-of-day)
-- - the offset determines where the "reference cycle" starts e.g. if the off=05;00;00 and int=03;45;00, starting from 0;05;00 the times would be
--   05;00, 08;45, ..., 20;00, 23;45, 1;03;30, then next cycle starts 1;05;00
-- - if the cycle is not a multiple of the interval like in the previous example, the very last instance is not considered when it is closer than interval/2 to the cycle boundary
--   in the example above the distance between 1;03;30 and 1;05;00 is only 90s, which is smaller than interval/2
--   It is preferred to therefore have a longer interval
--   and the actual sequence will be ..., 20;00, 23;45, 1;05;00

-- Get the time (in seconds) until the next time this rpt occurs
function rwt.time_to_next_rpt(rwtime, rpt_interval, rpt_offset)
	if not rpt_interval then rpt_interval = CYCLE end
	
	local rwtime_s = rwt.t_sec(rwtime)
	local rpti_s   = rwt.i_sec(rpt_interval)
	local rpto_s   = rwt.i_sec(rpt_offset)
	local otimcyc = (rwtime_s - rpto_s) % CYCLE -- time into current cycle, offset by the rpt offset
	-- otimcyc is the time into a cycle which is assumed to start at rpto_s
	local lasttime = otimcyc - (otimcyc % rpti_s)
	local nexttime = lasttime + rpti_s -- next occurence is last occurence plus interval
	
	if nexttime > (CYCLE - rpti_s/2) then -- last time cutoff rule, and overflow of cycle
		nexttime = CYCLE
	end
	
	return nexttime - otimcyc
end


-- Get the time (in seconds) since the last time this rpt occured
function rwt.time_from_last_rpt(rwtime, rpt_interval, rpt_offset)
	if not rpt_interval then rpt_interval = CYCLE end
	
	local rwtime_s = rwt.t_sec(rwtime)
	local rpti_s   = rwt.i_sec(rpt_interval)
	local rpto_s   = rwt.i_sec(rpt_offset)
	local otimcyc = (rwtime_s - rpto_s) % CYCLE -- time into current cycle, offset by the rpt offset
	-- otimcyc is the time into a cycle which is assumed to start at rpto_s
	local lasttime = otimcyc - (otimcyc % rpti_s)
	
	if lasttime > (CYCLE - rpti_s/2) then -- last time cutoff rule
		lasttime = lasttime - rpti_s
	end
	
	return otimcyc - lasttime
end

-- From rwtime, get the next time that is divisible by rpt_interval offset by rpt_offset
function rwt.next_rpt(rwtime, rpt_interval, rpt_offset)
	local time_to_next = rwt.time_to_next_rpt(rwtime, rpt_interval, rpt_offset)
	return rwt.add(rwtime, time_to_next)
end

-- from rwtime, get the last time that this rpt matched (which is actually just next_rpt - rpt_offset
function rwt.last_rpt(rwtime, rpt_interval, rpt_offset)
	local time_from_last = rwt.time_from_last_rpt(rwtime, rpt_interval, rpt_offset)
	return rwt.sub(rwtime, time_from_last)
end

function rwt.to_os_time(rwtime)
	local rw_now = rwt.to_secs(rwt.get_time())
	return rwt.to_secs(rwtime) - rw_now + os.time()
end

advtrains.lines.rwt = rwt

if core.get_modpath("ch_time") then
	ch_time.set_rwtime_callback(function()
		local rwtime = rwt.get_time()
		return {
			secs = rwt.to_secs(rwtime),
			string = rwt.to_string(rwtime, true),
			string_extended = rwt.to_string(rwtime),
		}
	end)
end
