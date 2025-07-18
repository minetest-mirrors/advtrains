-- advtrains_luaautomation/init.lua
-- Lua automation features for advtrains
-- Uses global table 'atlatc' (AdvTrains_LuaATC)



atlatc = { envs = {}}

-- Initialize internationalization (using ywang's poconvert)
advtrains.poconvert.from_flat("advtrains_luaautomation")
-- ask engine for translator instance, this will load the translation files
atlatc.translate = core.get_translator("advtrains_luaautomation")

-- Get current translator
local S = atlatc.translate

--Privilege
--Only trusted players should be enabled to build stuff which can break the server.
minetest.register_privilege("atlatc", { description = S("Can place and configure LuaATC components, including execute potentially harmful Lua code"), give_to_singleplayer = false, default= false })

--Size of code input forms in X,Y notation. Must be at least 10x10
atlatc.CODE_FORM_SIZE = "15,12"
--Position of Error Label in Code Form
atlatc.CODE_FORM_ERRLABELPOS = "0,12"

--assertt helper. error if a variable is not of a type
function assertt(var, typ)
	if type(var)~=typ then
		error("Assertion failed, variable has to be of type "..typ)
	end
end

local mp=minetest.get_modpath("advtrains_luaautomation")
if not mp then
	error("Mod name error: Mod folder is not named 'advtrains_luaautomation'!")
end
dofile(mp.."/environment.lua")
dofile(mp.."/interrupt.lua")
dofile(mp.."/active_common.lua")
dofile(mp.."/atc_rail.lua")
dofile(mp.."/operation_panel.lua")
if mesecon then
	dofile(mp.."/mesecon_controller.lua")
end
dofile(mp.."/pcnaming.lua")

dofile(mp.."/chatcmds.lua")

if minetest.settings:get_bool("advtrains_luaautomation_enable_atlac_recipes",false) == true then
	dofile(mp.."/recipes.lua")
end

local filename=minetest.get_worldpath().."/advtrains_luaautomation"

function atlatc.load(tbl)
	if tbl.version==1 then
		for envname, data in pairs(tbl.envs) do
			atlatc.envs[envname]=atlatc.env_load(envname, data)
		end
		atlatc.active.load(tbl.active)
		atlatc.interrupt.load(tbl.interrupt)
		atlatc.pcnaming.load(tbl.pcnaming)
	end
	-- run init code of all environments
	atlatc.run_initcode()
end

function atlatc.load_pre_v4()
	minetest.log("action", "[atlatc] Loading pre-v4 save file")
	local file, err = io.open(filename, "r")
	if not file then
		minetest.log("warning", " Failed to read advtrains_luaautomation save data from file "..filename..": "..(err or "Unknown Error"))
		minetest.log("warning", " (this is normal when first enabling advtrains on this world)")
	else
		atprint("luaautomation reading file:",filename)
		local tbl = minetest.deserialize(file:read("*a"))
		if type(tbl) == "table" then
			if tbl.version==1 then
				for envname, data in pairs(tbl.envs) do
					atlatc.envs[envname]=atlatc.env_load(envname, data)
				end
				atlatc.active.load(tbl.active)
				atlatc.interrupt.load(tbl.interrupt)
				atlatc.pcnaming.load(tbl.pcnaming)
			end
		else
			minetest.log("error", " Failed to read advtrains_luaautomation save data from file "..filename..": Not a table!")
		end
		file:close()
	end
	-- run init code of all environments
	atlatc.run_initcode()
end


atlatc.save = function()
	--versions:
	-- 1 - Initial save format.
	
	local envdata={}
	for envname, env in pairs(atlatc.envs) do
		envdata[envname]=env:save()
	end
	local save_tbl={
		version = 1,
		envs=envdata,
		active = atlatc.active.save(),
		interrupt = atlatc.interrupt.save(),
		pcnaming = atlatc.pcnaming.save(),
	}
	
	return save_tbl
end

--[[
-- globalstep for step code
local timer, step_int=0, 2

function atlatc.mainloop_stepcode(dtime)
	timer=timer+dtime
	if timer>step_int then
		timer=0
		atlatc.run_stepcode()
	end
end
]]
