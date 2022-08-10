return {
	{
		Str = function(elem)
			if elem.text == "Advtrains" then
				return pandoc.RawInline("latex", "\\advtrains{}")
			end
		end
	},
	{
		Header = function(elem)
			local attr = {
				class = "unnumbered unlisted",
			}
			return pandoc.Header(elem.level+1, elem.content, attr)
		end,
	},
	{
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
	},
}
