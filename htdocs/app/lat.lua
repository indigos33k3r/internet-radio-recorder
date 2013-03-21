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

local function escape_cmdline(self)
	return table.concat{'"', self:gsub('\\', '\\\\'):gsub('"', '\\"'), '"'}
end


function os.at(t,cmd,queue)
	if not queue then queue = 'a' end
	local at_cmd = table.concat{'echo ', escape_cmdline(cmd), ' | at -q ', queue, ' ', os.date('%H:%M %d.%m.%Y', t), ' 2>&1'}
	io.stderr:write(at_cmd, "\n")
	local f = assert(io.popen(at_cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
	-- io.stderr:write('at result: \'', s, "'\n")
	local _,_,jobnum = s:find('job%s+(%d+)%s+at%s+')
	jobnum = tonumber(jobnum)
	if jobnum then return jobnum end
	s = s:gsub('%s+$','')
	return nil,s
end


function os.atq(jobnum)
	if not jobnum then return nil,'No job number' end
	local f = assert(io.popen('atq	' .. tostring(assert(jobnum)), 'r'))
	local s = assert(f:read('*a'))
	f:close()
	local _,_,jobn,wday,month,day,hour,min,second,year = s:find('(%d+)%s+(%u%l%l)%s+(%u%l%l)%s+(%d+)%s+(%d%d):(%d%d):(%d%d)%s+(%d%d%d%d)%s+')
	if not jobn then
		return nil
	end
	-- io.stderr:write('expected job #', tostring(jobnum), ' found #', tonumber(jobn), "\n")
	-- assert( jobnum == tonumber(jobn) )
	-- local month_names = {'Jan','Feb','Mar','Apr','Mai','Jun','Jul','Aug','Sep','Oct','Nov','Dec'}
	-- local month2num = {}
	-- for i,n in ipairs(month_names) do month2num[n] = i end
	-- at seems to speak english no matter which locale is set. So we go with hardcoded month-names:
	local month2num = {Jan=1,Feb=2,Mar=3,Apr=4,Mai=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
	return tonumber(jobn),os.time({year=year, month=assert(month2num[month], month), day=day, hour=hour, min=min, second=second})
end


function os.atrm(jobnum)
	return os.execute('atrm ' .. jobnum)
end


function os.at_cat(jobnum)
	if true then
		return nil,'not implemented yet'
	end
	local f = assert(io.popen('at -c ' .. tostring(jobnum), 'r'))
	local s = assert(f:read('*a'))
	f:close()
	-- io.stderr:write('at result: \'', s, "'\n")
	local idx0,idx1,_ = s:find('unset OLDPWD')
	return s:sub(idx1+2):gsub('%s+$',''),s:sub(1,idx1)
end
