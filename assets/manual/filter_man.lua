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

		local page_names = {}
		for k, v in ipairs(meta.titles) do
			page_names[k] = utils.stringify(v)
		end
		local page_firstname = page_names[1]
		local page_section = utils.stringify(meta.section)
		local page_manual = utils.stringify(meta.manual)
		local page_firsttitle = string.format("%s(%s)", page_firstname, page_section)
		local page_shortdesc = meta.shortdesc

		-- add page title
		meta.title = pandoc.MetaString(string.format("%s | %s", text.upper(page_firsttitle), page_manual))
		local startidx = 1
		if is_latex then
			local titleid = string.format("man:%s.%s", page_firstname, page_section)
			local titleobj = pandoc.Header(1, pandoc.Code(page_firsttitle))
			titleobj.identifier = titleid
			blocks:insert(1, titleobj)
			for i = 2, #page_names do
				blocks:insert(i, pandoc.RawBlock("latex", string.format("\\label{man:%s.%s}", page_names[i], page_section)))
			end
			startidx = #page_names+1
		end

		-- insert naming information
		if is_man then
			blocks:insert(1, pandoc.Header(1, "NAME"))
			startidx = 2
		end
		local format_name = pandoc.Code
		if is_man then
			format_name = pandoc.Str
		end
		local nameinfo = pandoc.Plain(format_name(page_firstname))
		for i = 2, #page_names do
			nameinfo.content:insert(pandoc.Str(", "))
			nameinfo.content:insert(format_name(page_names[i]))
		end
		nameinfo.content:insert(pandoc.Str(" - "))
		nameinfo.content:extend(page_shortdesc)
		blocks:insert(startidx, nameinfo)
		startidx = startidx + 1

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
			if elem.text == "Advtrains" then
				return pandoc.SmallCaps("advtrains")
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
