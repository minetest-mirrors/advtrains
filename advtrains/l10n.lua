local S = minetest.get_translator("advtrains")

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
	nopriv = S_nopriv,
}
setmetatable(attrans, mt)
