require("mineunit")

mineunit("core")

_G.advtrains = {
	interlocking = {
		aspects = fixture("../../signal_aspects"),
	},
	ndb = {
		get_node = minetest.get_node,
	}
}

fixture("advtrains_helpers")
fixture("../../database")
sourcefile("signal_api")

local stub_aspect_t1 = { main = math.random() }
local stub_pos_t1 = {x = 1, y = 0, z = 1}

minetest.register_node(":stubsignal_t1", {
	advtrains = {
		supported_aspects = {},
		get_aspect = function () return stub_aspect_t1 end,
		set_aspect = function () end,
	},
	groups = { advtrains_signal = 2 },
})

world.layout {
	{stub_pos_t1, "stubsignal_t1"},
}

describe("API for supposed signal aspects", function()
	it("should load and save data properly", function()
		local tbl = {_foo = true}
		advtrains.interlocking.load_supposed_aspects(tbl)
		assert.same(tbl, advtrains.interlocking.save_supposed_aspects())
	end)
	it("should set and get type 1 signals properly", function ()
		local pos = stub_pos_t1
		local asp = stub_aspect_t1
		local newasp = { dst = math.random() }
		assert.same(asp, advtrains.interlocking.signal_get_aspect(pos))
		advtrains.interlocking.signal_set_aspect(pos, newasp)
		assert.same(newasp, advtrains.interlocking.signal_get_aspect(pos))
		assert.same(asp, advtrains.interlocking.signal_get_real_aspect(pos))
	end)
end)
