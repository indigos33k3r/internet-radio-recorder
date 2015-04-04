#!/usr/bin/env lua
--[[
-- Copyright (c) 2013-2015 Marcus Rohrmoser, https://github.com/mro/radio-pi
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
	io.write('Server: RadioPi 2013/lua', '\n')
	io.write('\n', 'I\'m not supposed to be run as cgi')
	io.write('\n')
	io.flush()
	os.exit(1)
end


-- ensure Recorder.lua (next to this file) is found:
package.path = arg[0]:gsub("/[^/]+/?$", '') .. "/?.lua;" .. package.path
require'Recorder'
Recorder.chdir2app_root( arg[0] )

if arg[1] == nil or arg[1] == '-?' or arg[1] == '-h'or arg[1] == '--help' then
	io.write([[re-match

Usage:
	$ app/podcast-match.lua [--dry-run] enclosures/b2/2013/01/20/1405\ musikWelt.xml

]])
	os.exit(0)
end


local dry_run = arg[1] == '--dry-run'
local bcs = {}
for i,bc_id in ipairs(arg) do
	local bc = Broadcast.from_file( bc_id )
	if bc then table.insert(bcs, bc) end
end

for i,bc in ipairs(bcs) do
	io.write('checkng ', bc.id, "\n")
	bc:match_podcasts()
	for _,pc in pairs( bc:podcasts() ) do
		io.write('matched ', pc.id, "\n")
	end
	if not dry_run then bc:save() end
end
