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


-- ensure Recorder.lua (next to this file) is found:
package.path = arg[0]:gsub('/[^/]+/?$', '') .. '/?.lua;' .. package.path
require('Recorder')
Recorder.chdir2app_root( arg[0] )

-- prepare, extract GET parameters:
local params = {}
local qs = os.getenv('QUERY_STRING')
if qs then for k,v in qs:gmatch('([^?&=]+)=([^&]*)') do
  params[k:unescape_url_param()] = v:unescape_url_param()
end end

-- guess station from GET params or referer:
local station_name = nil
if not station_name and params.station then station_name = params.station end
if not station_name and params.uri     then station_name = params.uri:match('stations/([^/]+)') end
local ref = os.getenv('HTTP_REFERER')
if not station_name and ref        then station_name = ref:match('stations/([^/]+)') end

local st = Station.from_id( station_name )
if not st then http_400_bad_request('Cannot guess station. Give me either\n', '- GET param station=...\n', '- GET param uri=...\n', '- a referer\n\n') end

local t = parse_iso8601( params.t )
local bc = st:broadcast_now(t or os.time(), true, false)
if bc then
  -- RFC 2616 http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1
  local fmt_date_rfc1123 = '!%a, %d %b %Y %H:%M:%S GMT'
  http_303_see_other('../stations/' .. bc.id:escape_url() .. '', nil, os.date(fmt_date_rfc1123, bc:dtend()))
else
  http_400_bad_request('Ouch, cannot find current broadcast for station: \'', station_name, '\'')
end
