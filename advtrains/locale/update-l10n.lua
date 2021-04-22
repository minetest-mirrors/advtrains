local lang = arg[1] or error("No language supplied")
local tfn = string.format("advtrains.%s.tr", lang)
local f = io.open(tfn, "rb") or error("Cannot read from translation file")
local tf = {}
for l in f:lines() do
	tf[#tf+1] = l
end
f:close()

local ot = {[0] = ""}
local f = io.open("template.txt", "rb") or error("Cannot read from translation template")
for l in f:lines() do
	if l == "" then -- blank line
		if ot[#ot] ~= l then ot[#ot+1] = l end
	elseif l:find("^#") then -- comment
		if ot[#ot] ~= l then ot[#ot+1] = l end
	else
		s = l:match("^(.+[^@]=)")
		if s then
			local found = false
			for i = 1, #tf, 1 do
				if tf[i]:find(s, 1, true) == 1 then
					found = i
					break
				end
			end
			if found then
				local fc = found-1
				while fc > 0 do
					if not tf[fc]:find("^#") then break end
					fc = fc-1
				end
				for i = fc+1, found, 1 do
					if ot[#ot] ~= tf[i] then ot[#ot+1] = tf[i] end
				end
			else
				if ot[#ot] ~= l then ot[#ot+1] = l end
			end
		end
	end
end
f:close()

local f = io.open(tfn..".new", "wb") or error("Cannot write to translation file")
f:write(table.concat(ot,"\n"))
f:close()