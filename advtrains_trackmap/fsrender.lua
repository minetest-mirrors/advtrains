-- fsrender.lua
-- Rendering of a grid of characters into a formspec

local tm = advtrains.trackmap

function tm.render_grid(grid, origin_pos, width, height)
	local s = {"label[0,0;"}
	for z=height-1, 0, -1 do
		-- render a row
		for x=0,width-1 do
			local apos_x = origin_pos.x + x
			local apos_z = origin_pos.z + z
			local chr = "░"
			if grid[apos_x] and grid[apos_x][apos_z] then
				chr = grid[apos_x][apos_z]
			end
			table.insert(s, chr)
		end
		table.insert(s,"\n")
	end
	table.insert(s, "]")
	return table.concat(s)
end