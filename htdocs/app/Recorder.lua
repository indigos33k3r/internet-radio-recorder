--[[
-- Copyright (c) 2013-2015 Marcus Rohrmoser, http://purl.mro.name/internet-radio-recorder
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

require'recorder-plumbing'
require'Station'
require'Broadcast'
require'Podcast'
require'Enclosure'

-- http://nova-fusion.com/2011/06/30/lua-metatables-tutorial/
-- http://lua-users.org/wiki/LuaClassesWithMetatable
Recorder = {}							-- methods table
Recorder_mt = { __index = Recorder }		-- metatable

function Recorder.chdir2app_root( arg0 )
	lfs.chdir( arg0:gsub("/[^/]+/?$", '') .. '/..' )
	Recorder.app_root = assert(lfs.currentdir())
	-- io.stderr:write('app root: ', Recorder.app_root, "\n")
end

function Recorder.base_url()
	if not Recorder._base_url then
		local f = assert(io.open('app/base.url', 'r'), 'No file app/base.url found')
		Recorder._base_url = f:read('*a'):gsub('%s', '')
		if '/' ~= Recorder._base_url:sub(1,-1) then
			Recorder._base_url = Recorder._base_url .. '/'
		end
		f:close()
	end
	return Recorder._base_url
end
