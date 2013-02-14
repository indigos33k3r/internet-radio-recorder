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

--
-- inject fake title, album and artist into streamripper for a given interval of time.
--
package.cpath = arg[0]:gsub('/[^/]+/?$', '') .. '/?.so;' .. package.cpath
-- see msleep.c and http://www.troubleshooters.com/codecorn/lua/lua_lua_calls_c.htm#_Make_an_msleep_Function
require('msleep')

local t_start   = tonumber(arg[1])
local t_end     = tonumber(arg[2])
data            = {ARTIST=arg[3], ALBUM=arg[4], TITLE=arg[5]}
local function echo_kv(idx)
    io.write(idx, '=', data[idx], "\n")
end

-- endless loop
while true do
    local t = os.time()
    if t < t_start then
        -- don't write a prefix, just wait.
    else
        if t > t_end then
            if data.TITLE ~= '' then
                data.ARTIST = ''
                data.ALBUM = ''
                data.TITLE = ''
            end
        else
            if data.ARTIST == nil or data.ARTIST == '' then data.ARTIST = 'artist' end
            if data.ALBUM  == nil or data.ALBUM  == '' then data.ALBUM  = 'album'  end
            if data.TITLE  == nil or data.TITLE  == '' then data.TITLE  = 'title'  end
        end
        table.foreach(data, echo_kv)
        io.write(".\n")
        io.flush()
    end
    local now = os.time()
    local dt = os.difftime(t_start, now)            -- how long until start?
    if dt < 0 then dt = os.difftime(t_end, now) end -- how long until end?
    if dt < 0 then dt = 5 end                       -- past end
    msleep( 1000 * math.max(0.01, math.min(0.1, dt) ) ) -- write every .1 second, but no more than every 1/100th sec
end
