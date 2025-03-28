-- depends on default, digilines and mesecons for crafting recipes
minetest.register_craft({
	output = "advtrains_luaautomation:dtrack_placer",
	recipe = {
		{"","mesecons_luacontroller:luacontroller0000",""},
		{"","advtrains:dtrack_atc_placer",""},
		{"","digilines:wire_std_00000000",""},
	}
})

minetest.register_craft({
	output = "advtrains_luaautomation:mesecon_controller0000",
	recipe = {
		{"","mesecons:wire_00000000_off",""},
		{"mesecons:wire_00000000_off","advtrains_luaautomation:dtrack_placer","mesecons:wire_00000000_off"},
		{"","mesecons:wire_00000000_off",""},
	}
})

minetest.register_craft({
	output = "advtrains_luaautomation:oppanel",
	recipe = {
		{"","mesecons_button:button_off",""},
		{"","advtrains_luaautomation:mesecon_controller0000",""},
		{"","default:stone",""},
	}
})