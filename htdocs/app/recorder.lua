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
if false and arg[1]:match('recorder%.lua$') and os.getenv('HTTP_HOST') then
	io.write('HTTP/1.1 400 Bad Request', '\n')
	io.write('Content-Type: text/plain', '\n')
	io.write('Server: Recorder 2013/lua', '\n')
	io.write('\n', 'I\'m not supposed to be run as cgi')
	io.write('\n')
	io.flush()
	os.exit(1)
end

require "luarocks.loader"	-- http://www.luarocks.org/en/Using_LuaRocks
local lfs = require "lfs"	-- http://keplerproject.github.com/luafilesystem/examples.html
-- local lpeg = require "lpeg" -- http://www.inf.puc-rio.br/~roberto/lpeg/

--- Sorted pairs iterator.
--
-- http://www.lua.org/pil/19.3.html
function pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0					-- iterator state
	local iter = function()		-- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

-- File Tools

local function dir_name(file_path)
	local _,_,parent = file_path:find("^(.*)/[^/]+/?$")
	return parent
end

function mkdir_recursive(dir)
	if 'directory' == lfs.attributes(dir,'mode') then return true end
	local parent = dir_name( dir )
	if parent ~= nil and parent ~= dir then
		local ok,msg = mkdir_recursive(parent)
		if not ok then return ok,msg end
	end
	return lfs.mkdir(dir)
end

local function touch_create(file_name)
	local ok,msg = mkdir_recursive( dir_name( file_name ) )
	if not ok then return ok,msg end
	local file, err = io.open( file_name, 'w+' )
	if file == nil then return false,err end
	ok,msg = file:write('')
	file:close()
	return ok,msg
end

local function file_write_if_changed(file, content, old)
	local created = false
	if not old then
		local old_f = io.open(file)
		if old_f then
			old = old_f:read('*all')
			old_f:close()
		else
			created = true
		end
	end
	if old == content then
		io.stderr:write('unchang ', file, '\n')
		return false,false
	end
	local dst,msg = io.open(file, 'w')
	if not dst then
		io.stderr:write('error	', msg, '\n')
		return false,false
	end
	dst:write(content)
	dst:close()
	io.stderr:write('written ', file, '\n')
	return true,created
end


-- http://lua-users.org/lists/lua-l/2008-03/msg00051.html
-- Takes a time struct with a date and time in UTC and converts it into
-- seconds since Unix epoch (0:00 1 Jan 1970 UTC).
--
-- Trickier than you'd think because os.time assumes the struct is in local time.
function utc2local(t_secs)
--	local t_secs = os.time(t) -- get seconds if t was in local time.
	t = os.date("*t", t_secs) -- find out if daylight savings was applied.
	local t_UTC = os.date("!*t", t_secs) -- find out what UTC t was converted to.
	t_UTC.isdst = t.isdst -- apply DST to this time if necessary.
	local UTC_secs = os.time(t_UTC) -- find out the converted time in seconds.
	-- The answer is our original answer plus the difference.
	return t_secs + os.difftime(t_secs, UTC_secs)
end


-- TODO: apply proper date/time parsing: http://stackoverflow.com/questions/7911322/lua-iso-8601-datetime-parsing-pattern
function parse_iso8601(iso)
	local year,month,day,hour,minute,second,tzh,tzm = iso:gmatch("(%d%d%d%d)-(%d%d)-(%d%d)T?%s?(%d%d):(%d%d):(%d%d)([+-]%d%d):?(%d%d)")()
	tzh = tonumber(tzh)
	hour = tonumber(hour) - tzh
	local sign = 1
	if tzh < 0 then sign = -1 end
	minute = tonumber(minute) - sign * tonumber(tzm)
	-- normalise time to current local time:
	return utc2local(os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day), hour=hour, min=minute, sec=tonumber(second)}))
end

local recorder = {
	stations = {}		-- cache (e.g. broadcast template per station)
}
recorder.touch = touch_create

-- Filesystem tools

local function recorder_broadcasts_siblings(root_dir,t_start,t_end,suffix,all)
	local min = {
		year	= os.date('%Y', t_start),
		month	= os.date('%m', t_start),
		day		= os.date('%d', t_start),
		time	= os.date('%H%M', t_start),
		t		= t_start,
	}
	local max = {
		year	= os.date('%Y', t_end),
		month	= os.date('%m', t_end),
		day		= os.date('%d', t_end),
		time	= os.date('%H%M', t_end),
		t		= t_end,
	}
	local reverse = t_start > t_end
	if reverse then min,max = max,min end
	local comp = function(a,b) return a < b end
	if reverse then comp = function(a,b) return a > b end end

	-- io.stderr:write('root: ', root_dir, '\n')
	years = {}
	local filter_year = function(year) return year:match('^%d%d%d%d$') and 'directory' == lfs.attributes(table.concat({root_dir,year},'/'), 'mode') end
	for year in lfs.dir( root_dir ) do
		if filter_year(year) then table.insert(years,year) end
	end
	table.sort(years, comp)
	local ret = {}
	for _,year in ipairs(years) do
		local t_year = os.time({
			year	= tonumber(year),
			month	= 1,
			day		= 1,
		})
		if year >= min.year and year <= max.year then
			months = {}
			local filter_month = function(month) return month:match('^%d%d$') and 'directory' == lfs.attributes(table.concat({root_dir,year,month},'/'), 'mode') end
			for month in lfs.dir( table.concat({root_dir,year},'/') ) do
				if filter_month(month) then table.insert(months,month) end
			end
			table.sort(months, comp)
			for _,month in ipairs(months) do
				local t_month = os.time({
					year	= tonumber(year),
					month	= tonumber(month),
					day		= 1,
				})
				if	(year > min.year or (year == min.year and month >= min.month))
				and (year < max.year or (year == max.year and month <= max.month))
				then
					days = {}
					local filter_day = function(day) return day:match('^%d%d$') and 'directory' == lfs.attributes(table.concat({root_dir,year,month,day},'/'), 'mode') end
					for day in lfs.dir( table.concat({root_dir,year,month},'/') ) do
						if filter_day(day) then table.insert(days,day) end
					end
					table.sort(days, comp)
					for _,day in ipairs(days) do
						local t_day = os.time({
							year	= tonumber(year),
							month	= tonumber(month),
							day		= tonumber(day),
						})
						if	(year > min.year or (year == min.year and month > min.month) or (year == min.year and month == min.month and day >= min.day))
						and (year < max.year or (year == max.year and month < max.month) or (year == max.year and month == max.month and day <= max.day))
						then
							times = {}
							local filter_time = function(time) return time:match('%d%d%d%d .*%.' .. suffix .. "$") and 'file' == lfs.attributes(table.concat({root_dir,year,month,day,time},'/'), 'mode') end
							for time in lfs.dir( table.concat({root_dir,year,month,day},'/') ) do
								if filter_time(time) then table.insert(times,time) end
							end
							table.sort(times, comp)
							for _,time in ipairs(times) do
								local t_time = os.time({
									year	= tonumber(year),
									month	= tonumber(month),
									day		= tonumber(day),
									hour	= tonumber(time:sub(1,2)),
									min		= tonumber(time:sub(3,4)),
								})
								if min.t <= t_time and t_time <= max.t then
									local f = table.concat({root_dir,year,month,day,time},'/')
									if not all then return {f} end
									table.insert(ret, f)
								end
							end
						end
					end
				end
			end
		end
	end
	return ret
end

local function recorder_broadcasts_sibling(self,next_)
	local t_min,t_max = os.time(self), os.time()
	if next_ then
		-- start +1min until +10 years
		t_min,t_max = t_min + 60, t_max + 10*365*24*60*60
	else
		-- start -1sec until -10 years
		t_min,t_max = t_min - 1, t_max - 10*365*24*60*60
	end
	local ret = recorder_broadcasts_siblings(table.concat{'stations','/',self.station_name},t_min,t_max,'xml',false)
	if not ret or table.getn(ret) == 0 then return nil end
	assert(table.getn(ret) == 1)
	return recorder.broadcast_from_file(ret[1])
end


-- String Tools

-- http://lua-users.org/wiki/StringRecipes
function recorder.unescape_url(str)
  str = str:gsub('+', ' ')
  str = str:gsub('%%(%x%x)', function(h) return string.char(tonumber(h,16)) end)
  return str:gsub("\r\n", "\n")
end

function recorder.unescape_xml_text(str)
	-- http://www.w3.org/TR/2008/REC-xml-20081126/#sec-references
	local entities = {
		['&amp;']	= '&',
		['&lt;']	= '<',
		['&gt;']	= '>',
		['&apos;']	= '\'',
		['&quot;']	= '"',
		['&#10;']	= "\n",
	}
	local subf = function(s)
		return entities[s] or s:gsub('&#(%x%x);', function(h) return string.char(tonumber(h,16)) end)
	end
	return str:gsub('(&[^;]+;)', subf)
end

-- inspired by https://github.com/henix/slt2
function recorder.escape_html_text(str)
	if str == nil then return '' end
	str = str:gsub('&', '&amp;')
	local tt = {
		['<'] = '&lt;',
		['>'] = '&gt;',
		['"'] = '&quot;',
		["'"] = '&apos;',
		["\n"] = '<br/>'
	}
	str = str:gsub('[<>"\'\n]', tt)
	return str
end


function recorder.escape_xml(str)
	if str == nil then return '' end
	local tt = {
		['<'] = '&lt;',
		['>'] = '&gt;',
		['"'] = '&quot;',
		["'"] = '&apos;',
	}
	str = str:gsub('&', '&amp;')
	str = str:gsub('[<>"\']', tt)
	return str
end

function recorder.escape_xml_attribute(str)
	if str == nil then return '' end
	local tt = {
		['<'] = '&lt;',
		['>'] = '&gt;',
		['"'] = '&quot;',
		["'"] = '&apos;',
		["\n"] = '&#10;'
	}
	return str:gsub('&', '&amp;'):gsub('[<>"\'\n]', tt)
end

function recorder.meta_key_to_xml(meta_key)
	return meta_key:gsub("_", ".")
end

function recorder.meta_key_to_lua(meta_key)
	return meta_key:gsub('%.', '_')
end

-- tbd

function recorder.chdir2app_root( arg0 )
	lfs.chdir( arg0:gsub("/[^/]+/?$", '') .. '/..' )
end


-- lookup/factory
local function station_by_name(name)
	local st = recorder.stations[name]
	if st == nil then
		local f = table.concat({'stations', name, 'app', 'station.cfg'}, '/')
		local m,msg = loadstring('return ' .. assert(io.open(f,'r'), '\'' .. f .. '\' not found.'):read('*a'))()
		assert(m.title, 'station title not set')
		assert(m.stream_url, 'station stream_url not set')
		assert(m.program_url, 'station program_url not set')
		assert(m.day_start, 'station daystart not set')
		assert(m.timezone, 'station timezone not set')
		st = {
			name = name,
			on_air = station_on_air,
		}
		for k,v in pairs(m) do st[k] = v end
		recorder.stations[name] = st
	end
	return st
end

-- return table w. <meta> plus xml source
-- TODO: sanity check found meta!
local function broadcast_meta_from_xml(xml_file)
	local metas,xml_old,file = {},nil,io.open(xml_file, 'r')
	if file == nil then return nil,nil end
	local xml_old = file:read('*a')
	file:close()
	for v,k in xml_old:gmatch('<meta%s+content=\'([^\']*)\'%s+name=\'(DC%.[^\']+)\'%s*/?>') do
		local k,v = recorder.unescape_xml_text(k),recorder.unescape_xml_text(v)
		metas[ recorder.meta_key_to_lua(k) ] = v
	end
	return metas,xml_old
end

local function broadcast_read_meta(self)
	io.stderr:write('read meta: ', self.file_xml, "\n")
	return broadcast_meta_from_xml(assert(self.file_xml, 'no xml file set.'))
end

local function broadcast_remove(self)
	if self:is_past() then
		return false,'mustn\'t be past'
	end
	io.stderr:write('remove	 ', self.file_xml, "\n")
	for _,pc_name in ipairs(self:podcast_names()) do
		self:podcast_remove(pc_name)
	end
	os.remove(self.file_xml)
	os.remove(self.file_podcast_json)
end

local function broadcast_to_xml(self, meta, xml_old)
	assert(self)
	assert(self.station)
	assert(self.station.name)
	assert(self.day_dir)
	assert(self.base)
	local xml_file = self.file_xml
	if meta == nil then meta = self.meta end
	if meta ~= nil
		then _,xml_old = broadcast_meta_from_xml(xml_file)
		else meta,xml_old = broadcast_meta_from_xml(xml_file)
	end
	assert(type(meta) == 'table')

	local ret = {
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<?xml-stylesheet type="text/xsl" href="../../../app/broadcast2html.xslt"?>',
    	'<!-- Dublin Core PBMI http://dcpapers.dublincore.org/pubs/article/view/749 -->',
		'<!-- not: Ontology for Media Resources 1.0 http://www.w3.org/TR/mediaont-10/ -->',
		'<!-- not: EBU http://tech.ebu.ch/lang/en/MetadataEbuCore -->',
		'<broadcast xmlns="https://raw.github.com/mro/radio-pi/master/htdocs/app/pbmi2003-recmod2012/broadcast.rnc">',
	}
	for _,k in ipairs({
		'DC.scheme', 'DC.language', 'DC.title', 'DC.title.series', 'DC.title.episode',
		'DC.format.timestart', 'DC.format.timeend', 'DC.format.duration', 'DC.image',
		'DC.description', 'DC.publisher', 'DC.creator', 'DC.copyright', 'DC.source',
	}) do
		local v = meta[ recorder.meta_key_to_lua(k) ]
		local row = {'    <meta content=\'', recorder.escape_xml_attribute( v ), '\' name=\'', k, '\'/>'}
		table.insert( ret, table.concat(row) )
	end
	table.insert( ret, '</broadcast>' )
	local xml_new = table.concat(ret,"\n")

	mkdir_recursive(self.dir_xml)
	-- TODO: remove all other files during this time interval (xml, podcast, enclosure - recreate if ad_hoc?)
	local t0,t1 = os.time(self),parse_iso8601(self.meta.DC_format_timeend)
	for f in lfs.dir(self.dir_xml) do
		local bc = recorder.broadcast_from_file(table.concat({self.dir_xml, f}, '/'))
		if bc then
			local bc_t = os.time(bc)
			if t0 <= bc_t and bc_t < t1 and nil == self.file_xml:find(bc.file_xml,1,true) then
				bc:remove()
			end
		end
	end
	return file_write_if_changed(xml_file, xml_new, xml_old)
end

-- write podcast json like
-- { "podcasts": [ "ad_hoc", "krimi" ] }
local function broadcast_to_podcast_json(self)
	-- io.stderr:write('to_podcast_json()', "\n")
	local pcns = self:podcast_names()
	if table.getn(pcns) > 0 then
		local t = table.concat{'{ "podcasts":[{"name":"', table.concat(pcns,'"},{"name":"'), '"}] }'}
		file_write_if_changed(self.file_podcast_json, t)
	else
		os.remove( self.file_podcast_json )
	end
end

-- Enclosure stuff

local function string_has_prefix(s, prefix)
	if s == nil and prefix == nil	then return true end
	if s == nil or prefix == nil	then return false end
	local l = prefix:len()
	if s:len() < l			then return false end
	return s:sub(1,l) == prefix
end

local function recorder_broadcast_timeend(self)
	local ret = self._timeend
	if ret == nil then
		if self.meta == nil then self.meta = self:read_meta() end
		ret = parse_iso8601(assert(self.meta.DC_format_timeend, 'need DC_format_timeend'))
		self._timeend = ret
	end
	return ret
end

local function recorder_broadcast_is_past(self,now)
	if now == nil then now = os.time() end
	if os.time(self) < now then
		-- already started, but still running?
		if recorder_broadcast_timeend(self) < now then
			-- io.stderr:write('I\'m past: ', 'enclosures', '/', self.day_dir, '/', self.base, "\n")
			return true
		end
	end
	return false
end


--- Query the state of an enclosure.
-- @param self a broadcast as from recorder.broadcast_from_file
-- @return 'none', 'pending'
-- @see recorder.broadcast_from_file
local function recorder_broadcast_enclosure_state(self)
	assert(self, 'need a broadcast')
	local s = self._enclosure_state
	if s == nil then
		s = 'none'
		local scan_dir = table.concat{'enclosures', '/', self.day_dir}
		local base_len = self.base:len()
		if 'directory' == lfs.attributes(scan_dir, 'mode') then
			for file in lfs.dir(scan_dir) do
				local base_f = file:sub(1, base_len)
				if self.base == base_f then
					if 'file' == lfs.attributes(table.concat{scan_dir, '/', file}, 'mode') then
						s = file:sub( base_len + 2, -1 )
						break
					end
				end
			end
		end
		self._enclosure_state = s
	end
	return s
end

local function recorder_broadcast_enclosure_schedule(self)
	assert(self, 'need a broadcast')
	if self:is_past() then return false,'Already past' end
	local scan_dir = table.concat{'enclosures', '/', self.day_dir}
	local base_pending = table.concat{self.base, '.pending'}
	if 'file' == lfs.attributes(table.concat{scan_dir, '/', base_pending}, 'mode') then
		io.stderr:write('unchang ', 'enclosures', '/', self.day_dir, '/', self.base, '.xml', "\n")
		return true,nil
	end
	if 'directory' == lfs.attributes(scan_dir, 'mode') then
		for file in lfs.dir(scan_dir) do
			if file == base_pending then return true,nil end
			if string_has_prefix(file, self.base) then
				return false,'I\'m blocked'
			end
		end
	end
	local file = table.concat{scan_dir, '/', base_pending}
	touch_create(file)
	self._enclosure_state = nil
	io.stderr:write('schedld ', self.day_dir, '/', self.base, '.xml', "\n")
	return true,nil
end

local function recorder_broadcast_enclosure_unschedule(self)
	-- check if any .pending etc. there already?
	local file = table.concat{'enclosures', '/', self.day_dir, '/', self.base, '.pending'}
	os.remove( file )
	self._enclosure_state = nil
	return true,nil
end

local function recorder_broadcast_podcast_names(self)
	ret = self._podcast_names
	if ret == nil then
		local tmp = {}
		for podcast_name in lfs.dir( 'podcasts' ) do
			local f = table.concat{'podcasts', '/', podcast_name, '/', self.day_dir}
			if 'directory' == lfs.attributes(f, 'mode') then
				for marker in lfs.dir( f ) do
					if string_has_prefix(marker, self.base) then
						-- io.stderr:write(podcast_name, "\n")
						tmp[podcast_name] = marker
					end
				end
			end
		end
		ret = {}
		for pcn,_ in pairs(tmp) do table.insert(ret, pcn) end
		table.sort(ret)
		self._podcast_names = ret
	end
	return ret
end

local function recorder_broadcast_podcast_add(self, podcast_name)
	if podcast_name == 'ad_hoc' then
		if table.getn(recorder_broadcast_podcast_names(self)) > 0 then
			return false,'cannot add to ad_hoc if already in a podcast'
		end
	end
	if 'directory' ~= lfs.attributes( table.concat{'podcasts', '/', podcast_name}, 'mode' ) then
		return false,'no such podcast'
	end
	touch_create( table.concat{'podcasts', '/', podcast_name, '/', self.day_dir, '/', self.base, '.xml' } )
	self._podcast_names = nil
	return recorder_broadcast_enclosure_schedule(self)
end

local function recorder_broadcast_podcast_remove(self, podcast_name)
	local pc_f = table.concat{'podcasts', '/', podcast_name, '/', self.day_dir, '/', self.base, '.xml' }
	if 'file' ~= lfs.attributes( pc_f, 'mode' ) then
		return false,'no such podcast'
	end
	if self:is_past() then
		return false,'mustn\'t be past'
	end
	os.remove( pc_f )
	self._podcast_names = nil
	if table.getn(self:podcast_names()) == 0 then
		return recorder_broadcast_enclosure_unschedule(self)
	end
	return true,nil
end

local function recorder_broadcast_prev(self)
	return recorder_broadcasts_sibling(self, false)
end

local function recorder_broadcast_next(self)
	return recorder_broadcasts_sibling(self, true)
end

--- ctor
-- @param bc_file path to a xml file, must include station name and the rest.
-- @param meta optional
function recorder.broadcast_from_file(bc_file, meta)
	local section,sta,year,month,day,hour,min,title,ext = bc_file:match("([^/]+)/([^/]+)/(%d%d%d%d)/(%d%d)/(%d%d)/(%d%d)(%d%d) (.*)%.([^/%.]*)$")
	if not sta then
		return nil,'can\'t figure out station from \'' .. bc_file .. '\''
	end
	local t = {
		section = section,
		station_name = sta,
		station = station_by_name(sta),
		day_dir = table.concat{sta, '/', year, '/', month, '/', day},
		base	= table.concat{hour, min, ' ', title},
		ext		= ext,
		year	= tonumber(year),
		month	= tonumber(month),
		day		= tonumber(day),
		hour	= tonumber(hour),
		min		= tonumber(min),
		title	= title,
		meta	= meta,
		read_meta		= broadcast_read_meta,
		enclosure_state = recorder_broadcast_enclosure_state,
		podcast_names	= recorder_broadcast_podcast_names,
		podcast_add		= recorder_broadcast_podcast_add,
		podcast_remove	= recorder_broadcast_podcast_remove,
		is_past			= recorder_broadcast_is_past,
		timeend			= recorder_broadcast_timeend,
		to_xml			= broadcast_to_xml,
		to_podcast_json	= broadcast_to_podcast_json,
		remove			= broadcast_remove,
		prev_sibling	= recorder_broadcast_prev,
		next_sibling	= recorder_broadcast_next,
	}
	t.dir_xml = table.concat({'stations', t.day_dir}, '/')
	t.file_xml = table.concat{t.dir_xml, '/', t.base, '.xml'}
	t.file_podcast_json = table.concat{t.dir_xml, '/', t.base, '.json'}
	return t
end

--- Find latest broadcast smaller or equal time_max
--
-- @return a broadcast as of recorder.broadcast_from_file or nil plus a message.
function recorder.station_find_most_recent_before(station_name, time_max, section, state, reverse)
	assert(station_name, "No station given")
	assert(section, "No section given")
	assert(time_max, "No time given")
	reverse = reverse or false
	local day_dir = table.concat({section, station_name, os.date('%Y/%m/%d', time_max)}, '/')
	if 'directory' ~= lfs.attributes(day_dir, 'mode') then return nil, "no dir: '" .. day_dir .. "'" end
	if not state then state = '' end
	local pat = "(%d%d%d%d) .*%." .. state
	local hit = '' -- smallest possible string
	if reverse then hit = 'z' end
	local time_cutoff = os.date('%H%M', time_max)
	for f in lfs.dir(day_dir) do
		local _,_,t = f:find(pat)
		if reverse then
			if t and f < hit and t >= time_cutoff then hit = f end
		else
			if t and f > hit and t <= time_cutoff then hit = f end
		end
	end
	if hit == '' then
		return nil,'none due <= ' .. os.date("%Y-%m-%d %H:%M:%S", time_max)
	else
		return recorder.broadcast_from_file( table.concat({day_dir, hit}, '/') )
	end
end

-- podcasts
local slt2 = require "slt2"	-- http://github.com/henix/slt2

local function podcast_template_rss(self)
	local tmpl = self.template_rss_
	if not tmpl then
		local file = table.concat({ 'podcasts', assert(self.name), 'app', 'podcast.slt2.rss'}, '/')
		-- io.stderr:write('loading template \'', file, '\'\n')
		tmpl = slt2.loadfile(file)
		self.template_rss_ = tmpl
		io.stderr:write('loaded template ', file, '\n')
	end
	return tmpl
end

local function podcast_to_rss(self)
	local rss_file = table.concat{'podcasts', '/', assert(self.name), '.rss'}
	local rss_new = slt2.render(assert(self:template_rss()), {podcast=self})
	return file_write_if_changed(rss_file, rss_new)
end


local function podcast_broadcasts(self, comp)
	local root_dir = table.concat{'podcasts', '/', self.name}
	-- pick up all broadcasts
	local tmp = {}
	io.stderr:write('root: ', root_dir, '\n')
	for station_name in lfs.dir( root_dir ) do
		local station_dir = table.concat{root_dir, '/', station_name}
		-- io.stderr:write('station: ', station_dir, '\n')
		if station_name ~= '.' and station_name ~= '..' and 'directory' == lfs.attributes(station_dir, 'mode') then
			for year in lfs.dir( station_dir ) do
				local year_dir = table.concat{station_dir, '/', year}
				-- io.stderr:write('year: ', year_dir, '\n')
				if year:match('%d%d%d%d') and 'directory' == lfs.attributes(year_dir, 'mode') then
					for month in lfs.dir( year_dir ) do
						local month_dir = table.concat{year_dir, '/', month}
						-- io.stderr:write('month: ', month_dir, '\n')
						if month:match('%d%d') and 'directory' == lfs.attributes(month_dir, 'mode') then
							for day in lfs.dir( month_dir ) do
								local day_dir = table.concat{month_dir, '/', day}
								-- io.stderr:write('day: ', day_dir, '\n')
								if day:match('%d%d') and 'directory' == lfs.attributes(day_dir, 'mode') then
									for bc_file in lfs.dir( day_dir ) do
										local bc = recorder.broadcast_from_file( table.concat{day_dir, '/', bc_file} )
										if bc then
											-- io.stderr:write('found broadcast ', bc.file_xml, '\n')
											table.insert(tmp, bc)
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if not comp then
		comp = function(a,b) return a.file_xml < b.file_xml end
	end
	table.sort(tmp, comp)
	return tmp
end

function recorder.podcast_from_name(podcast_name)
	local ret = {
		name = assert(podcast_name, 'podcast name is nil'),
		-- functions. Maybe use a meta table?
		to_rss			= podcast_to_rss,
		template_rss	= podcast_template_rss,
		broadcasts		= podcast_broadcasts,
	}
	local f = table.concat({'podcasts', podcast_name, 'app', 'podcast.cfg'}, '/')
	if 'file' == lfs.attributes(f, 'mode') then
		local m,msg = loadstring('return ' .. assert(io.open(f,'r'), '\'' .. f .. '\' not found.'):read('*a'))()
		for k,v in pairs(m) do ret[k] = v end
	else
		return nil,'no podcast: ' .. podcast_name
	end
	return ret
end

function recorder.podcasts_all()
	if recorder.podcasts == nil then
		local ret = {}
		for podcast_name in lfs.dir( 'podcasts' ) do
			local p,msg = recorder.podcast_from_name(podcast_name)
			if p then
				ret[ podcast_name ] = p
				io.stderr:write('registered podcast ', podcast_name, '\n')
			end
		end
		recorder.podcasts = ret
	end
	return recorder.podcasts
end

return recorder