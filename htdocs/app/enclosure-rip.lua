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
if os.getenv('HTTP_HOST') then
	io.write('HTTP/1.1 400 Bad Request', '\n')
	io.write('Content-Type: text/plain', '\n')
	io.write('Server: Recorder 2013/lua', '\n')
	io.write('\n', 'I\'m not supposed to be run as cgi')
	io.write('\n')
	io.flush()
	os.exit(1)
end




-- ensure recorder.lua (next to this file) is found:
package.path = arg[0]:gsub("/[^/]+/?$", '') .. "/?.lua;" .. package.path
rec = require('recorder')
rec.chdir2app_root( arg[0] )

if arg[1] == nil or arg[1] == '-?' or arg[1] == '-h'or arg[1] == '--help' then
	io.write([[streamripper convenience wrapper and watchdog a.k.a. blocking rip.

Usage:
	$ app/enclosure-rip.lua --due b2
	$ app/enclosure-rip.lua enclosures/b2/2013/01/20/1405\ musikWelt.html

]])
	os.exit(0)
end

--- figure out if streamripper as started by myself is already running
-- 
-- TODO: mask single quotes
-- @return true/false
local function enclosure_is_ripping(bc)
	local ps = assert(io.popen('ps ux'), "Cannot call 'ps ux'")
	local pat = table.concat{'/usr/bin/streamripper', ".* %-d '([^']*/", bc.day_dir, '/', bc.base, ")' %-D '%.%./"}
	for line in ps:lines() do
		local hit,_ = line:match(pat)
		if nil ~= hit then return true end
	end
	ps:close()
	return false
end

--- launch streamripper
-- 
-- renames .pending in .ripping and leaves a bunch of mp3s in ./incomplete
-- 
-- @return true
local function enclosure_streamripper_run(bc, tmp_dir)
	local meta		= assert(bc:read_meta(), "Couldn't read meta from '" ..  tmp_dir .. "'")
	local t_start	= assert(parse_iso8601(meta.DC_format_timestart), "Couldn't get timestart from '" ..  tmp_dir .. "'")
	local t_end		= assert(parse_iso8601(meta.DC_format_timeend), "Couldn't get timeend from '" ..  tmp_dir .. "'")
	assert(mkdir_recursive(tmp_dir), "couldn't create dir '" .. tmp_dir .. "'")
	if 'ripping' ~= bc:enclosure_state() then
		assert(os.rename( table.concat{tmp_dir, '.pending'}, table.concat{tmp_dir, '.ripping'}))
	end
	local rip_tail = 15	-- add to mp3
	local rip_post = 5	-- keep streamripper running post recording
	while os.time() < t_end do
		io.stderr:write("starting rip ", tmp_dir, " until ", os.date('%Y-%m-%d %H:%M:%S', t_end + rip_tail), "\n")
		local params = {
			" /usr/bin/streamripper",
			" '", assert(bc.station.stream_url, 'stream url not found'), "'",
			" -t",
			" -l ", math.max(0, os.difftime(t_end, os.time()) + rip_tail + rip_post),
			" -u '", "iTunes/11.0.1 (Macintosh; OS X 10.7.5) AppleWebKit/534.57.7", "'",
			" -s", -- Don´t create a directory for each stream
			" -d '", tmp_dir, "'", -- The destination directory		-- todo: mask quotes!
			" -D '", "..", "/", assert(bc.base, 'bc.base not set'), "'",	-- file to create	-- todo: mask quotes!
			" -o version",
			" -E '", "app/streamripper-injector.lua ", t_start, ' ', t_end + rip_tail, "'",
			" 1>> '", tmp_dir, "/", "stdout.log'",					-- todo: mask quotes!
			" 2>> '", tmp_dir, "/", "stderr.log'",					-- todo: mask quotes!
			""
		}
		io.stderr:write('streamripper result ', os.execute(table.concat(params)), "\n")
	end
	return true
end

--- consolidate mp3 snippets from ./incomplete into one mp3 file.
-- 
-- uses 'cat' to concatenate the mp3s into .ripping and renames into .mp3.
-- 
-- removes ./incomplete, but leaves stdout.log and stderr.log.
-- 
-- @return -
local function enclosure_mp3_consolidate(bc, tmp_dir)
	-- pick up mp3 snippets (relative) file names into a unsorted table
	local mp3s_unsorted = {}
	local mp3_dir = table.concat({tmp_dir, 'incomplete'}, '/')
	for mp3_file in lfs.dir(mp3_dir) do
		-- print(mp3_file)
		local i1,i2,s = mp3_file:find('artist %- title(.*)%.mp3')
		if i1 then
			if s == '' then s = 10000
			else s = tonumber(s:sub(3,-2)) end
			mp3s_unsorted[s] = mp3_file
		elseif mp3_file ~= '.' and mp3_file ~= '..' then
			-- remove pre- + post recordings
			assert(os.remove(table.concat{mp3_dir, '/', mp3_file}))
		end
	end
	
	-- sort mp3 snippet (relative) file names
	local mp3s_sorted = {}
	for i,f in pairsByKeys(mp3s_unsorted) do table.insert(mp3s_sorted, f) end
	mp3s_unsorted = nil
	
	-- synth cat command to write mp3 snippets into .ripping file (sic!)
	local cat_cmd = {}
	table.insert(cat_cmd, "cat \\\n")
	for i,f in ipairs(mp3s_sorted) do
		table.insert(cat_cmd, "  '")
		table.insert(cat_cmd, mp3_dir)	-- TODO: mask quotes
		table.insert(cat_cmd, "/")
		table.insert(cat_cmd, f)		-- TODO: mask quotes
		table.insert(cat_cmd, "' \\\n")
	end
	table.insert(cat_cmd, "  > '")
	table.insert(cat_cmd, tmp_dir)		-- TODO: mask quotes
	table.insert(cat_cmd, ".ripping")
	table.insert(cat_cmd, "'")
	-- io.stderr:write(table.concat(cat_cmd), "\n")
	assert( 0 == os.execute(table.concat(cat_cmd)), "failed to concatenate mp3s")
	cat_cmd = nil
	
	-- remove now concatenated mp3s
	for i,f in ipairs(mp3s_sorted) do
		assert( os.remove(table.concat{mp3_dir, '/', f}) )
	end
	mp3s_sorted = nil
	-- clean up 'incomplete' dir
	assert( os.remove(mp3_dir) )
	-- rename .ripping into .mp3
	assert( os.rename(table.concat{tmp_dir, ".ripping"}, table.concat{tmp_dir, ".mp3"}) )
	return true
end


-- time = { year=2013, month=1, day=22, hour=23, min=03 }
-- print(station_find_first_due('b2', 'enclosures', os.time(time), 'pending').base)
-- os.exit(100)

local bc = nil
if arg[1] == '--due' then
	bc = rec.station_find_most_recent_before( arg[2], os.time() + 3*60, 'enclosures', 'pending' )
	if bc == nil then
		io.write('Nothing due. ', arg[2], "\n")
		os.exit(0)
	end
	if enclosure_is_ripping(bc) then
		io.write("already ripping '", bc.file_html, "'", "\n")
		os.exit(0)
	end
else
	bc = assert(rec.broadcast_from_file(arg[1]), "couldn't use broadcast")
end

local tmp_dir = table.concat({'enclosures', bc.day_dir, bc.base}, '/')
assert( 'pending' == bc:enclosure_state() or 'ripping' == bc:enclosure_state(), "enclosure '" ..  tmp_dir .. "' isn't pending not ripping.")
bc.meta = assert( bc:read_meta(), "couldn't read meta for " .. bc.file_html)
assert( not bc:is_past(), "broadcast '" ..  tmp_dir .. "' is already past.")
assert( not enclosure_is_ripping(bc), "ripper '" ..  tmp_dir .. "' is already running.")
assert( enclosure_streamripper_run(bc, tmp_dir) )
assert( enclosure_mp3_consolidate(bc, tmp_dir) )

-- id3tag
os.execute('nice app/enclosure-tag.rb \'' .. table.concat{'enclosures', '/', bc.day_dir, '/', bc.base, '.mp3'} .. '\'')

-- re-render html ?

-- re-render rss !
for _,podcast_name in ipairs(bc:podcast_names()) do
	rec.podcast_from_name(podcast_name):to_rss()
end

os.exit(0)

