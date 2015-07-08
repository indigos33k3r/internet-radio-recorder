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

-- ensure Recorder.lua (next to this file) is found:
package.path = arg[0]:gsub('/[^/]+/?$', '') .. '/../../app/?.lua;' .. package.path
require('Recorder')
Recorder.chdir2app_root( arg[0]:gsub('/[^/]+/?$', '') .. '/../../app/foo.lua' )

if 'POST' ~= os.getenv('REQUEST_METHOD') then http_400_bad_request('need POST.') end

local len = tonumber(os.getenv('CONTENT_LENGTH'))
local body = io.read(len)
local key,value = body:match('^([^=]+)=(.*)$')
if 'referer' ~= value then http_400_bad_request('bad value') end

local bc_http = os.getenv('HTTP_REFERER')
if not bc_http then http_400_bad_request('Odd, no broadcast (HTTP_REFERER) set.') end
local bc = Broadcast.from_file( bc_http:unescape_url() )
if not bc then http_400_bad_request('No usable broadcast (HTTP_REFERER) set: \'', bc_http, '\'') end
if bc:is_past() then http_400_bad_request('broadcast already past: \'', bc_http, '\'') end

-- clean up env and set PATH + LANG
local psx = require('posix')
for k,v in pairs(psx.getenv()) do
	if k ~= 'PATH' and k ~= 'LANG' then psx.setenv(k,nil) end
end
if not psx.getenv('LANG') and not os.setlocale('en_US.UTF-8') and not os.setlocale('en_GB.UTF-8') and not os.setlocale('de_DE.UTF-8') then
	http_400_bad_request('Cannot set locale')
end
if not psx.getenv('LANG') then psx.setenv('LANG', 'en_US.UTF-8') end
if not psx.getenv('PATH') then psx.setenv('PATH', '/bin:/usr/bin:/usr/local/bin') end

local ad_hoc = assert(Podcast.from_id('ad_hoc'))

if key == 'add' and 'none' == bc:enclosure().state then
	bc:add_podcast(ad_hoc)
elseif key == 'remove' and 'pending' == bc:enclosure().state then
	bc:remove_podcast(ad_hoc)
else
	bc:save()	-- repair in case
	http_400_bad_request('Cannot modify broadcast \'', bc_http, '\' in state \'', bc:enclosure().state, '\' with action \'', key, '\'')
end

local ok,msg = bc:save()
-- ok,msg = bc:save_podcast_json()
if not ok then http_400_bad_request(msg, ' ', bc_http) end
http_303_see_other(bc_http, 'Good choice, it\'s my pleasure to record that broadcast. Sending you back...')
