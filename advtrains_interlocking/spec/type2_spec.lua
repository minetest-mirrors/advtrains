require "mineunit"
mineunit("core")

_G.advtrains = {
	interlocking = {
		aspects = sourcefile("signal_aspects"),
	},
	ndb = {
		get_node = minetest.get_node,
		swap_node = minetest.swap_node,
	}
}

fixture("advtrains_helpers")
sourcefile("database")
sourcefile("signal_api")
sourcefile("distant")
sourcefile("signal_aspect_accessors")

local A = advtrains.interlocking.aspects
local D = advtrains.distant
local I = advtrains.interlocking
local N = advtrains.ndb

local type2def = {
	name = "foo",
	main = {
		{name = "proceed", main = -1},
		{name = "caution"},
		{name = "danger", main = 0},
	},
}

local asps = {}
for _, v in pairs(type2def.main) do
	minetest.register_node("advtrains_interlocking:" .. v.name, {
		advtrains = {
			supported_aspects = {
				type = 2,
				group = "foo",
			},
			get_aspect = function() return v.name end,
			set_aspect = function(pos, _, name)
				N.swap_node(pos, {name = "advtrains_interlocking:" .. name})
			end,
		}
	})
	asps[v.name] = {
		main = v.main,
		type2group = "foo",
		type2name = v.name,
	}
end

local origin = vector.new(0, 0, 0)
local dstpos = vector.new(0, 0, 1)

world.layout {
	{origin, "advtrains_interlocking:danger"},
	{dstpos, "advtrains_interlocking:proceed"},
}

describe("type 2 signal group registration", function()
	it("should work", function()
		A.register_type2(type2def)
		assert(A.get_type2_definition("foo"))
	end)
	it("should only be allowed once for the same group", function()
		assert.has.errors(function() A.register_type2(type2def) end)
	end)
	it("should handle nonexistant groups", function()
		assert.is_nil(A.get_type2_definition("something_else"))
	end)
end)

describe("signal aspect conversion", function()
	it("should work for converting from type 1 to type 2", function()
		assert.equal("danger", A.type1_to_type2main({main = 0}, "foo"))
		assert.equal("caution", A.type1_to_type2main({main = 6}, "foo"))
		assert.equal("proceed", A.type1_to_type2main({}, "foo"))
	end)
	-- Type 2 -> type 1 conversion is tested with signal aspect accessors
end)

describe("type 2 signals", function()
	it("should support distant signaling", function()
		assert.equal("caution", A.get_type2_dst("foo", 3))
		assert.equal("proceed", A.get_type2_dst("foo", "caution"))
		assert.equal("proceed", A.get_type2_dst("foo", "proceed"))
	end)
	it("should work with accessors", function()
		assert.same(asps.danger, I.signal_get_aspect(origin))
		local newasp = {type2group = "foo", type2name = "proceed", main = 6}
		I.signal_set_aspect(origin, newasp)
		assert.same(newasp, I.signal_get_aspect(origin))
	end)
	it("should work with distant signaling", function()
		assert.same(asps.proceed, I.signal_get_aspect(dstpos))
		local dstasp = {type2group = "foo", type2name = "proceed", dst = 6, main = -1}
		D.assign(origin, dstpos)
		assert.same(dstasp, I.signal_get_aspect(dstpos))
	end)
end)
