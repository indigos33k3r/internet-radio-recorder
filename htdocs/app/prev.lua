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


-- ensure recorder.lua (next to this file) is found:
package.path = arg[0]:gsub('/[^/]+/?$', '') .. '/?.lua;' .. package.path
rec = require('recorder')
rec.chdir2app_root( arg[0] )
-- lfs.chdir( arg[0]:gsub('/[^/]+/?$', '') .. '/../..' )

local function http_400_bad_request(...)
	io.write('HTTP/1.1 400 Bad Request', '\n')
	io.write('Content-Type: text/plain', '\n')
	io.write('Server: Recorder 2013/lua', '\n')
	io.write('\n', ...)
	io.write('\n')
	io.flush()
	os.exit(0)
end

local function http_303_see_other(uri)
	io.write('HTTP/1.1 303 See Other', '\n')
	io.write('Content-Type: text/plain', '\n')
	io.write('Server: Recorder 2013/lua', '\n')
	io.write('Location: ', uri, '\n')
	io.write('\n')
	io.flush()
end

if 'GET' ~= os.getenv('REQUEST_METHOD') then http_400_bad_request('need POST.') end
-- if 'referer' ~= value then http_400_bad_request('bad value') end

local bc_http = os.getenv('HTTP_REFERER')
if not bc_http then http_400_bad_request('Odd, no broadcast (HTTP_REFERER) set.') end

local bc = rec.broadcast_from_file( rec.unescape_url(bc_http) )
if not bc then http_400_bad_request('No usable broadcast (HTTP_REFERER) set: \'', bc_http, '\'') end

local sib,msg = bc:prev_sibling()
if sib then
	http_303_see_other('../../../../../' .. sib.file_html)
else
	http_303_see_other('../../../../../' .. bc.file_html)
end
