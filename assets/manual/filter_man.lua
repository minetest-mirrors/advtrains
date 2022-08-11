local text, utils = pandoc.text, pandoc.utils

local filters = {}

local function add_filter(x)
	table.insert(filters, x)
end

local is_latex = FORMAT:match "latex"
local is_man = FORMAT:match "man"

add_filter {
	Pandoc = function(elem)
		local blocks, meta = elem.blocks, elem.meta

		local page_title = utils.stringify(meta.title)
		local page_manual = utils.stringify(meta.manual)
		local page_name, page_section = page_title:match("^([^%(]+)%(([^%)]+)%)$")

		-- add page title
		meta.title = pandoc.MetaString(string.format("%s | %s", text.upper(page_title), page_manual))
		if is_latex then
			local titleid = string.format("man:%s.%s", page_name, page_section)
			local titleobj = pandoc.Header(1, pandoc.Code(page_title))
			titleobj.identifier = titleid
			blocks:insert(1, titleobj)
		end

		-- add "See Also" section
		local seealso = elem.meta.seealso
		if not seealso then
			return elem
		end
		blocks:insert(pandoc.Header(1, pandoc.Str("See Also")))
		if is_man then
			for k, v in pairs(seealso) do
				seealso[k] = utils.stringify(v)
			end
			blocks:insert(pandoc.Plain(table.concat(seealso, ", ")))
		else
			local list = {}
			for _, i in ipairs(seealso) do
				local page = utils.stringify(i)
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
			if (elem.identifier or ""):match("^man:") then
				return elem -- do not modify title header
			end
			local attr = {
				class = "unnumbered unlisted",
			}
			return pandoc.Header(elem.level+1, elem.content, attr)
		end,
	}
end

if is_man then
	add_filter {
		Header = function(elem)
			local filter = {
				Str = function(elem)
					return pandoc.Str(text.upper(elem.text))
				end,
				Code = function(elem)
					return pandoc.Str(elem.text)
				end,
			}
			return pandoc.walk_block(elem, filter)
		end
	}
end

return filters
