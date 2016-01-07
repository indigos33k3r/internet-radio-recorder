#!/usr/bin/env lua
--[[
-- Copyright (c) 2013-2016 Marcus Rohrmoser, http://purl.mro.name/recorder
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

if arg[1] == nil or arg[1] == '-?' or arg[1] == '--help' then
  io.write([[
Usage:

  display this help info
  $ broadcast-render.lua --help

  update/create broadcasts from meta data
  $ broadcast-render.lua --stdin
]])
  os.exit(0)
end

-- ensure recorder.lua (next to this file) is found:
package.path = arg[0]:gsub('/[^/]+/?$', '') .. '/?.lua;' .. package.path
require('Recorder')
Recorder.chdir2app_root( arg[0] )
-- local prof = require 'profiler'
-- prof.start()

-- multiple xml files to create/update
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
  local time_limit_min = os.time()
  -- DO only overwrite already started or past broadcasts if explicitely told
  if arg[2] == '--update-past' then time_limit_min = 0 end
  local process = function(meta)
    local bc = Broadcast.from_meta(meta)
    if bc:dtstart() <= time_limit_min then return bc:filename('xml'),'ignored' end -- never overwrite already started or past broadcasts
    bc:match_podcasts()
    return bc:save()
  end
  for _,meta in ipairs(metas) do
    local ok,file,msg,err = pcall(process, meta)
    if ok then
      -- io.stderr:write(msg, ' ', file, "\n")
    else
      io.stderr:write('error: ', file, "\n")
    end
  end
  os.exit(0)
end

assert(false,'not supported')
