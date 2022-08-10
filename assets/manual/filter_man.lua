local filters = {}

local function add_filter(x)
	table.insert(filters, x)
end

local is_latex = FORMAT:match "latex"
local is_man = FORMAT:match "man"

add_filter {
	Pandoc = function(elem)
		local seealso = elem.meta.seealso
		if not seealso then
			return
		end
		local blocks = elem.blocks
		blocks:insert(pandoc.Header(1, pandoc.Str("SEE ALSO")))
		if is_man then
			for k, v in pairs(seealso) do
				seealso[k] = v[1].text
			end
			blocks:insert(pandoc.Plain(table.concat(seealso, ", ")))
		else
			local list = {}
			for _, i in ipairs(seealso) do
				local page = i[1].text
				local pgname, pgsection = string.match(page, "^([^%)]+)%(([^%)]+)%)$")
				local item = pandoc.Plain(page)
				if is_latex and pgname and pgsection then
					pgname = pgname:gsub("_","\\string_")
					item = pandoc.RawBlock("latex", string.format("\\manref{%s}{%s}", pgname, pgsection))
				end
				table.insert(list, item)
			end
			blocks:insert(pandoc.BulletList(list))
		end
		return elem
	end
}

if is_latex then
	add_filter {
		Str = function(elem)
			if elem.tex == "Advtrains" then
				return pandoc.RawInline("latex", "\\advtrains{}")
			end
		end
	}
	add_filter {
		Header = function(elem)
			local attr = {
				class = "unnumbered unlisted",
			}
			return pandoc.Header(elem.level+1, elem.content, attr)
		end,
	}
	add_filter {
		Pandoc = function(elem)
			local outputfn = PANDOC_STATE.output_file or error("No output file specified")
			local pgname, pgsection = outputfn:match("([^%./\\]+)%.([^%.]+)%.tex$")
			assert(pgname and pgsection, "Cannot fetch manpage name and section")
			local blocks = elem.blocks
			local titlestr = string.format("%s(%s)", pgname, pgsection)
			local titleid = string.format("man:%s.%s", pgname, pgsection)
			local titleobj = pandoc.Header(1, pandoc.Code(titlestr))
			titleobj.identifier = titleid
			blocks:insert(1, titleobj)
			return elem
		end,
	}
end

return filters
