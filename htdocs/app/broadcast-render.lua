#!/usr/bin/env lua
--[[
-- Copyright (c) 2013 Marcus Rohrmoser, https://github.com/mro/br-recorder
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
if os.getenv('HTTP_HOST') then
	io.write('HTTP/1.1 400 Bad Request', '\n')
	io.write('Content-Type: text/plain', '\n')
	io.write('Server: Recorder 2013/lua', '\n')
	io.write('\n', 'I\'m not supposed to be run as cgi')
	io.write('\n')
	io.flush()
	os.exit(1)
end

if arg[1] == nil or arg[1] == '-?' or arg[1] == '--help' then
    io.write([[
Usage:

  display this help info
  $ broadcast-render.lua --help

  update/create broadcasts from meta data
  $ broadcast-render.lua --stdin

  re-render multiple broadcasts
  $ broadcast-render.lua a.html ...
]])
    os.exit(0)
end

-- ensure recorder.lua (next to this file) is found:
package.path = arg[0]:gsub('/[^/]+/?$', '') .. '/?.lua;' .. package.path
rec = require('recorder')
rec.chdir2app_root( arg[0] )
-- local prof = require 'profiler'
-- prof.start()

function recorder_podcast_broadcast_match(podcast,bc)
	local ok,match = pcall(assert(assert(podcast, 'podcast').match, 'match'), assert(bc.meta, 'meta'))
	if ok then return match end
	io.write('error! ', 'podcasts', '/', assert(podcast.name, 'podcast name'), ' ', bc.day_dir, '/', bc.base, ' ', match, '\n')
	return nil, match
end

function recorder_process_podcast_all_matches(bc)
	for _,podcast in pairs( rec.podcasts_all() ) do
		podcast.broadcast_match = recorder_podcast_broadcast_match
		if podcast:broadcast_match(bc) then
			io.stderr:write('match! ', podcast.name, ' ', bc.file_html, '\n')
			bc:podcast_add(podcast.name)
		end
	end
end


-- multiple html files to create/update
if arg[1] == '--stdin' then
	local metas,err = loadstring(table.concat{'return {', io.read('*a'), '}'})
    if metas == nil then
    	io.write('error: ', err, "\n")
    	os.exit(1)
    end
    local ok,metas = pcall(metas)
    if not ok then
    	io.write('error: ', metas, "\n")
    	os.exit(1)
    end
	-- table.sort(metas, function(a,b) return a.DC_format_timestart < b.DC_format_timestart end)
    for _,meta in ipairs(metas) do
    	-- fake file_html to avoid 2nd ctor:
    	local station_name = assert(meta.station, 'missing key \'station\'')
    	local dtstart = parse_iso8601(assert(meta.DC_format_timestart, 'missing key \'DC_format_timestart\''))
		local file_html = table.concat{'stations', '/', station_name, '/', os.date('%Y/%m/%d/%H%M', dtstart), ' ', meta.title, '.html'}
		meta.title = nil
		meta.t_download_start = nil
  		meta.t_scrape_start = nil
  		meta.t_scrape_end = nil
		local bc = assert(rec.broadcast_from_file(file_html, meta))

		bc.process_podcast_matches = recorder_process_podcast_all_matches
    	-- exchange nachtmix image? http://www.br.de/layout/img/programmfahne/nachtmix112~_v-image256_-a42a29b6703dc477fd0848bc845b8be5c48c1667.jpg?version=1314966146489
		bc:process_podcast_matches()	-- move to lib recorder.lua?
		assert('table' == type(assert(bc.meta, 'need meta')))
    	bc:to_html()
    end
    os.exit(0)
end

-- multiple html files to re-render
for idx,bc_file in ipairs(arg) do
    if idx > 0 then
		local bc = rec.broadcast_from_file(bc_file)
		bc.process_podcast_matches = recorder_process_podcast_all_matches
        local meta,html_old = bc:read_meta()
        bc.meta = meta
		assert(bc.meta, 'need meta')
		bc:process_podcast_matches()	-- move to lib recorder.lua?
    	bc:to_html(meta, html_old)
    end
end
