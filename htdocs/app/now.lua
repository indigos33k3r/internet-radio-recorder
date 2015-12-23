#!/usr/bin/env lua
--[[
-- Copyright (c) 2013-2015 Marcus Rohrmoser, http://purl.mro.name/recorder
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

-- guess station from GET params or url:
local station_name = nil
if not station_name and params.station then station_name = params.station end
if not station_name and params.uri     then station_name = params.uri:match('stations/([^/]+)') end

local fmt_date_rfc1123_2utc = '!' .. '%a, %d %b %Y %H:%M:%S GMT'

local t = parse_iso8601( params.t ) or os.time()

if station_name then
  -- redirect to one dedicated station/broadcast
  local st = Station.from_id( station_name )
  if not st then
    http_400_bad_request('Unknown station \'', station_name, '\'. Give me either\n', '- GET param station=...\n', '- GET param uri=...\n', '- a referer\n\n')
  end

  local bc = st:broadcast_now(t, true, false)
  if bc then
    -- RFC 2616 http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1
    http_303_see_other('../stations/' .. bc.id:escape_url() .. '', nil, os.date(fmt_date_rfc1123_2utc, bc:dtend()))
  else
    http_400_bad_request('Ouch, cannot find current broadcast for station: \'', station_name, '\'')
  end
else
  -- list all stations' current broadcasts
  local xml = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<?xml-stylesheet type="text/xsl" href="../assets/broadcasts2html-now.xslt"?>',
    '<!-- unorthodox relative namespace to enable http://www.w3.org/TR/grddl-tests/#sq2 without a central server -->',
    '<broadcasts xml:lang="de" xmlns="../assets/2013/radio-pi.rdf">',
  }
  local file_mod = 0
  for _,st in orderedPairs(Station.each()) do
    local bc = st:broadcast_now(t, true, false)
    if bc then
      file_mod = math.max(file_mod, bc:modified(), bc:dtstart())
      bc:to_xml(xml)
    end
  end
  table.insert( xml, '</broadcasts>' )
  local head = {
    ['Content-Type']  = 'text/xml',
    ['Last-Modified'] = os.date(fmt_date_rfc1123_2utc, file_mod),
    ['Expires']       = os.date(fmt_date_rfc1123_2utc, os.time() + 10),
  }
  file_mod = os.time(os.date('!*t', file_mod))
  local ifmod = parse_date_rfc1123( os.getenv('HTTP_IF_MODIFIED_SINCE'), 0 )
  if file_mod > ifmod then
    http_200_ok(head, table.concat(xml, "\n") )
  else
    http_304_unmodified(head)
  end
end
