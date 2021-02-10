package.path  =  "../?.lua;" .. package.path
advtrains = {}
_G.advtrains = advtrains
function _G.attrans(...) return ... end
function advtrains.invert_train() end
function advtrains.train_ensure_init() end

local atcjit = require("atcjit")

local function assert_atc(train, warn, err, res)
	local w, e = atcjit.execute(train.id,train)
	assert.same(err, e)
	if w then assert.same(warn, w) end
	assert.same(res, train)
end

local function thisatc(desc, train, warn, err, res)
	it(desc, function() assert_atc(train, warn, err, res) end)
end

describe("simple ATC track", function()
	local t = {
		atc_arrow = true,
		atc_command = " B12WB8WBBWOLD15ORD15OCD1RS10WSM",
		door_open = 0,
		max_speed = 20,
		tarvelocity = 10,
		velocity = 0,
	}
	thisatc("should make the train slow down to 12", t, {}, nil,{
		atc_arrow = true,
		atc_brake_target = 12,
		atc_command = "B8WBBWOLD15ORD15OCD1RS10WSM",
		atc_wait_finish = true,
		door_open = 0,
		max_speed = 20,
		tarvelocity = 10,
		velocity = 0,
	})
	thisatc("should make the train brake to 8", t, {}, nil, {
		atc_arrow = true,
		atc_brake_target = 8,
		atc_command  = "BBWOLD15ORD15OCD1RS10WSM",
		atc_wait_finish = true,
		door_open = 0,
		max_speed = 20,
		tarvelocity = 8,
		velocity = 0,
	})
	thisatc("should make the train stop", t, {}, nil, {
		atc_arrow = true,
		atc_brake_target = -1,
		atc_command = "OLD15ORD15OCD1RS10WSM",
		atc_wait_finish = true,
		door_open = 0,
		max_speed = 20,
		tarvelocity = 0,
		velocity = 0,
	})
	thisatc("should make the train open its left doors", t, {}, nil, {
		atc_arrow = true,
		atc_brake_target = -1,
		atc_command = "ORD15OCD1RS10WSM",
		atc_delay = 15,
		atc_wait_finish = true,
		door_open = -1,
		max_speed = 20,
		tarvelocity = 0,
		velocity = 0,
	})
	thisatc("should make the train open its right doors", t, {}, nil,{
		atc_arrow = true,
		atc_brake_target = -1,
		atc_command = "OCD1RS10WSM",
		atc_delay = 15,
		atc_wait_finish = true,
		door_open = 1,
		max_speed = 20,
		tarvelocity = 0,
		velocity = 0,
	})
	thisatc("should make the train close its doors", t, {}, nil, {
		atc_arrow = true,
		atc_brake_target = -1,
		atc_command = "RS10WSM",
		atc_delay = 1,
		atc_wait_finish = true,
		door_open = 0,
		max_speed = 20,
		tarvelocity = 0,
		velocity = 0,
	})
	thisatc("should make the train depart and accelerate to 10", t, {}, nil, {
		atc_arrow = true,
		atc_brake_target = -1,
		atc_command = "SM",
		atc_delay = 1,
		atc_wait_finish = true,
		door_open = 0,
		max_speed = 20,
		tarvelocity = 10,
		velocity = 0,
	})
	thisatc("should make the train accelerate to 20", t, {}, nil, {
		atc_arrow = true,
		atc_brake_target = -1,
		atc_delay = 1,
		atc_wait_finish = true,
		door_open = 0,
		max_speed = 20,
		tarvelocity = 20,
		velocity = 0,
	})
end)

describe("ATC track with whitespaces", function()
	local t = {
		atc_command = " \t\n OC \n S20 \r "
	}
	thisatc("should not cause errors", t, {}, nil, {
		door_open = 0,
		tarvelocity = 20,
	})
end)

describe("empty ATC track", function()
	local t = {atc_command = ""}
	thisatc("should not do anything", t, {}, nil, {})
end)

describe("ATC track with nested I statements", function()
	local t = {
		atc_arrow = false,
		atc_command = "I+OREI>5I<=10S16WORES12;D15;;OC",
		velocity = 10,
		door_open = 0,
	}
	thisatc("should make the train accelerate to 16", t, {}, nil,{
		atc_arrow = false,
		atc_command = "ORD15OC",
		atc_wait_finish = true,
		velocity = 10,
		door_open = 0,
		tarvelocity = 16,
	})
end)

describe("ATC track with invalid statement", function()
	local t = { atc_command = "Ifoo" }
	thisatc("should report an error", t, {}, "Invalid command or malformed I statement: Ifoo", t)
end)

describe("ATC track with invalid I condition", function()
	local t = { atc_command = "I?;" }
	thisatc("should report an error", t, {}, "Invalid I statement", t)
end)

describe("ATC track reusing existing code", function()
	local t = { atc_command = " B12WB8WBBWOLD15ORD15OCD1RS10WSM", tarvelocity = 15 }
	thisatc("should do the same thing as in the first test", t, {}, nil, {
		atc_brake_target = 12,
		atc_command = "B8WBBWOLD15ORD15OCD1RS10WSM",
		atc_wait_finish = true,
		tarvelocity = 12
	})
end)

describe("ATC track reusing malformed code", function()
	local t = {atc_command = "I?;"}
	thisatc("should report the invalid I statement", t, {}, "Invalid I statement", t)
end)

describe("ATC track that sets ARS modes", function()
	local t = {atc_command = "A0WA1WAFWAT"}
	thisatc("should disable ARS on the train with A0", t, {}, nil, {atc_wait_finish=true, ars_disable=true,  atc_command="A1WAFWAT"})
	thisatc("should enable ARS on the train with A1",  t, {}, nil, {atc_wait_finish=true, ars_disable=false, atc_command="AFWAT"})
	thisatc("should disable ARS on the train with AF", t, {}, nil, {atc_wait_finish=true, ars_disable=true,  atc_command="AT"})
	thisatc("should enable ARS on the train with AT",  t, {}, nil, {atc_wait_finish=true, ars_disable=false,})
end)