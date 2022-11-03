--- Advtrains l10n module.
-- Advtrains' l10n module is built on top of
-- [Minetest's](https://minetest.gitlab.io/minetest/translations/).
-- @module attrans
-- @alias mt

--- Wrapper for `minetest.translate`.
-- Note that this function is also called when calling the `attrans`
-- *table* itself. Doing so is encourged as `attrans.attrans` is only
-- intended for situations where only functions are accepted.
-- @function attrans
-- @param str The string to translate.
-- @param[opt] ... Additional arguments to pass to `minetest.translate`.
local S = minetest.get_translator("advtrains")

--- Generate an error message that a user does not have a specific privilege.
-- @function nopriv
-- @param priv The privilege that is missing.
-- @param[opt] verb The action that is denied.
-- @param[optchain] ... Additional arguments to pass to `minetest.translate`.
local function S_nopriv(priv, verb, ...)
	if verb then
		return S(string.format("You are not allowed to %s without the %s privilege.", verb, priv), ...)
	else
		return S("You do not have the @1 privilege.", priv)
	end
end

local mt = {
	__call = function(_, ...)
		return S(...)
	end,
}

attrans = {
	attrans = S,
	nopriv = S_nopriv,
}
setmetatable(attrans, mt)
