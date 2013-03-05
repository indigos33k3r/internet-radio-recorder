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


-- ensure Recorder.lua (next to this file) is found:
package.path = arg[0]:gsub('/[^/]+/?$', '') .. '/?.lua;' .. package.path
require('Recorder')
Recorder.chdir2app_root( arg[0] )

if 'GET' ~= os.getenv('REQUEST_METHOD') then http_400_bad_request('need GET.') end
-- if 'referer' ~= value then http_400_bad_request('bad value') end

local bc_xml = os.getenv('HTTP_REFERER')
if not bc_xml then http_400_bad_request('Odd, no broadcast (HTTP_REFERER) set.') end

local bc = Broadcast.from_file( bc_xml:unescape_url() )
if not bc then http_400_bad_request('No usable broadcast (HTTP_REFERER) set: \'', bc_xml, '\'') end

local sib,msg = bc:prev_sibling()
if sib then
	http_303_see_other('../../../../../stations/' .. sib.id .. '.xml')
else
	http_303_see_other('../../../../../stations/' .. bc.id .. '.xml')
end
