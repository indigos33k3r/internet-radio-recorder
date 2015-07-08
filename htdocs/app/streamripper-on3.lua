#!/usr/bin/env lua
--[[
-- Copyright (c) 2013-2015 Marcus Rohrmoser, http://purl.mro.name/radio-pi
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

require 'luarocks.loader'	-- http://www.luarocks.org/en/Using_LuaRocks

--
-- grab artist + title from http://www.br.de/on3/welle116~liveHeader.jsp
--

http = require 'socket.http'
local function scrape_playlist_tracks(now)
	local t0 = now or os.time()
	local d0 = os.date('*t', t0)
	local b,c,h = http.request('http://www.br.de/on3/welle116~liveHeader.jsp')	
	local rows = {}
	for clz,txt in b:gmatch('class="playlist_([^"]+)"[^>]*>([^<]*)</') do
		-- io.stderr:write(clz,txt,"\n")
		table.insert(rows, { [clz] = txt })
	end
	-- group 3 entries into one, ascending acc. time
	assert( #rows % 3 == 0)
	local play_list = {}
	for i = #rows,3,-3 do
		local item = {}
		for j = 0,2,1 do for k,v in pairs(rows[i-j]) do item[k] = v end end
		if item.time then
			local h,m = item.time:match('(%d%d):(%d%d) Uhr')
			local time = {
				year = d0.year,
				month = d0.month,
				day = d0.day,
				hour = assert(tonumber(h)),
				min = assert(tonumber(m)),
			}
			-- assume tracks to be less than 11h...
			if d0.hour > time.hour + 11 then time.day = time.day + 1 end
			item.time = os.time(time)
			item.artist = assert(item.interpret)
			item.interpret = nil
			table.insert(play_list, 1, item)
		end
	end
	return play_list	
end

local psx = require'posix'
local function msleep(msecs)
	psx.nanosleep(msecs / 1000, (msecs % 1000) * 1000)
end

local stream_delay_sec = 3
local last_scraped	= 0
local track 		= {}

-- endless loop
while true do
    local now = os.time() - stream_delay_sec
    if track.future and now >= track.future.time then
    	io.stderr:write('switch: ', track.current.title, "\n")
    	track.current,track.future = track.future,nil
    elseif not track.future and os.difftime(now,last_scraped) >= 30 then -- no more often than 30sec
		io.stderr:write('scrape..', "\n")
		track.future = nil
		for _,tr in ipairs( scrape_playlist_tracks(now) ) do
			io.stderr:write('> ', os.date('%H:%M', tr.time), ' ', tr.title, ' - ', tr.artist, "\n")
			if tr.time <= now		then track.current = tr
			elseif not track.future then track.future = tr
			end
		end
		last_scraped = now
		io.stderr:write('current ', os.date('%H:%M', track.current.time), ' ', track.current.title, ' - ', track.current.artist, "\n")
		if track.future then
			io.stderr:write('future  ', os.date('%H:%M', track.future.time), ' ', track.future.title, ' - ', track.future.artist, "\n")
		end
	end
    io.write('ARTIST', '=', track.current.artist, "\n")
    io.write('ALBUM', '=', 'streamripper', "\n")
    io.write('TITLE', '=', track.current.title, "\n")
	io.write(".\n")
	io.flush()

    local dt = 1
    msleep( 1000 * math.max(0.01, math.min(0.1, dt) ) ) -- write every .1 second, but no more than every 1/100th sec
end
