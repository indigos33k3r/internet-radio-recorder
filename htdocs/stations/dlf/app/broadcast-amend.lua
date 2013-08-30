#!/usr/bin/env lua
--[[
-- Copyright (c) 2013 Marcus Rohrmoser, https://github.com/mro/radio-pi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
-- associated documentation files (the "Software"), to deal in the Software without restriction,
-- including without limitation the rights to use, copy, modify, merge, publish, distribute,
-- sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
-- NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
-- OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- MIT License http://opensource.org/licenses/MIT
]]


-- TODO: apply proper date/time parsing: http://stackoverflow.com/questions/7911322/lua-iso-8601-datetime-parsing-pattern
local function parse_iso8601_local(iso)
	if not iso then return nil,'nil' end
    local year,month,day,hour,minute,second = iso:match("^(%d%d%d%d)-?(%d%d)-?(%d%d)[T ]?(%d%d):?(%d%d):?(%d%d)$")
	if not year then return nil,'cannot parse \'' .. iso .. '\'' end
	minute = tonumber(minute)
	local date = { year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = minute, sec = tonumber(second) }
	return os.time(date)
end

function string:to_lua()
	return self:gsub('\\', '\\\\'):gsub('\'', '\\\''):gsub('\n', '\\n')
end

local function write_meta(meta)
	if meta then
		io.write('-- comma separated lua tables, one per broadcast:\n')
		io.write('{', '\n')		
		for k,v in pairs(meta) do
			if k:sub(1,6) ~= 'local_' then
				io.write('  ', k, ' = \'', tostring(v):to_lua(), '\',\n')
			end
		end
	  io.write('},', '\n', '\n')		
	end
end

local metas,err = loadstring(table.concat{'return {', io.read('*a'), '}'})
if metas == nil then
	io.stderr:write('error: ', err, '\n')
	os.exit(1)
end
local ok,metas = pcall(metas)
if not ok then
	io.stderr:write('error: ', metas, '\n')
	os.exit(1)
end


local prev = nil
for _,meta in ipairs(metas) do
	local t_start,err = parse_iso8601_local(meta.DC_format_timestart)
	if t_start and meta.DC_title then
		meta.station = 'dlf'
		meta.DC_scheme = '/app/pbmi2003-recmod2012/'
		meta.DC_source = 'http://www.dradio.de/dlf/vorschau/'
		meta.DC_relation = nil
		meta.DC_title = meta.DC_title:gsub('%s+$', '')
		meta.title = meta.DC_title
		meta.DC_description = meta.DC_description:gsub('%s+$', '')
		-- meta.DC_author = meta.DC_copyright
		-- meta.DC_publisher = meta.DC_copyright
		meta.DC_format_timestart = os.date('%FT%H:%M:%S%z', t_start)
		if prev then
			prev.DC_format_timeend = meta.DC_format_timestart
			prev.DC_format_duration = t_start - prev.local_start
		end
		write_meta(prev)
		prev = meta
		prev.local_start = t_start
	end
end
prev.DC_format_timeend = prev.DC_format_timestart:gsub('T%d%d:%d%d:%d%d', 'T24:00:00')
prev.DC_format_duration = parse_iso8601_local(prev.DC_format_timestart:gsub('T%d%d:%d%d:%d%d.*$', 'T24:00:00')) - prev.local_start

write_meta(prev)
