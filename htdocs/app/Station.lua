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

-- http://nova-fusion.com/2011/06/30/lua-metatables-tutorial/
-- http://lua-users.org/wiki/LuaClassesWithMetatable
Station = {}							-- methods table
Station_mt = { __index = Station }		-- metatable

Station._stations = {}

function Station.from_id(id)
	local st = Station._stations[id]
	if not st then
		local f = table.concat({'stations', id, 'app', 'station.cfg'}, '/')
		local fh,msg = io.open(f,'r')
		if not fh then return nil,msg end
		local m,msg = loadstring('return ' .. assert(fh, msg):read('*a'))()
		fh:close()
		io.stderr:write('loading ', f, "\n")
		local tbl = {
			id = assert(id),
			title = assert(m.title, 'station title not set'),
			stream_url = assert(m.stream_url, 'station stream_url not set'),
			program_url = assert(m.program_url, 'station program_url not set'),
			day_start = assert(m.day_start, 'station daystart not set'),
			timezone = assert(m.timezone, 'station timezone not set'),
		}
		st = setmetatable( tbl, Station_mt )
		Station._stations[id] = st
	end
	return st
end


function lfs.dir_sorted(base,compare)
	local sorted = {}
	for f in lfs.dir(base) do
		table.insert(sorted, f)
	end
	table.sort(sorted,compare)
	return ipairs(sorted)
end


function lfs.files_between(base, tmin, tmax, callback, future)
	if not tmin then tmin = 0 end
	if not tmax then tmax = 100*365*24*60*60 end
	local dmin = os.date('*t', tmin)
	local dmax = os.date('*t', tmax)
	local compare = nil
	if future then
		compare = function(a,b) return a < b end -- natural order, ASC
	else
		compare = function(a,b) return a > b end -- DESC
	end
	-- io.stderr:write('tmin: ', os.date('%Y-%m-%d %H:%M', tmin), "\n")
	-- io.stderr:write('tmax: ', os.date('%Y-%m-%d %H:%M', tmax), "\n")
	-- io.stderr:write('futu: ', tostring(future), "\n")
	for _,ys in lfs.dir_sorted(base,compare) do
		local y = tonumber(ys)
		-- io.stderr:write(ys, "\n")
		if y and dmin.year <= y and y <= dmax.year then
			for _,ms in lfs.dir_sorted(table.concat({base,ys},'/'),compare) do
				-- io.stderr:write(ys, '-', ms, "\n")
				local m = tonumber(ms)
				if not m or (dmin.year == y and m < dmin.month) or (dmax.year == y and m > dmax.month) then
				else
					for _,ds in lfs.dir_sorted(table.concat({base,ys,ms},'/'),compare) do
						-- io.stderr:write(ys, '-', ms, '-', ds, "\n")
						local d = tonumber(ds)
						if not d or (dmin.year == y and dmin.month == m and d < dmin.day) or (dmax.year == y and dmax.month == m and d > dmax.day) then
						else
							for _,f in lfs.dir_sorted(table.concat({base,ys,ms,ds},'/'),compare) do
								-- io.stderr:write(ys, '-', ms, '-', ds, ' ', f)
								local ok,_,hos,mis = f:find('^(%d%d)(%d%d) ')
								if ok then
									local t = os.time{year=y,month=m,day=d,hour=hos,min=mis}
									if tmin <= t and t <= tmax then
										-- io.stderr:write(' callback')
										if callback(table.concat({base,ys,ms,ds,f},'/'),t) then
											return
										end
									end
								end
								-- io.stderr:write("\n")
							end
						end
					end
				end
			end
		end
	end
end


-- find first one smaller or equal t
function Station:broadcast_now(t,onlyfirst,future)
	if t == nil then t = os.time() end
	local tmin,tmax = nil,t
	if future then tmin,tmax = tmax,tmin end
	local candidate = nil
	lfs.files_between(table.concat({'stations',self.id},'/'), tmin, tmax,
		function(path)
			if '.xml' == path:sub(-4) then
				candidate = Broadcast.from_file( path )
				return true
			end
		end,
		future
	)
	return candidate
end

local slt2 = require "slt2" -- http://github.com/henix/slt2

function Station:template_ics()
	local tmpl = self.template_ics_
	if not tmpl then
		local file = table.concat({ 'stations', assert(self.id), 'app', 'station.slt2.ics'}, '/')
		-- io.stderr:write('loading template \'', file, '\'\n')
		tmpl = slt2.loadfile(file)
		self.template_ics_ = tmpl
		io.stderr:write('loaded template ', file, '\n')
	end
	return tmpl
end

function Station:save_ics(tmin,tmax)
	tmin = tmin or (os.time() - 3 * 60 * 60)
	tmax = tmax or (tmin + 6 * 60 * 60)
	-- io.stderr:write('t.b.d., ics for station ', self.id, "\n")
	local broadcasts = {}
	lfs.files_between(table.concat({'stations',self.id},'/'), tmin, tmax,
		function(path)
			if '.xml' == path:sub(-4) then
				table.insert(broadcasts, Broadcast.from_file( path ) )
				return false
			end
		end,
		true
	)
	local ics_file = table.concat{'stations', '/', assert(self.id), '/broadcasts.ics'}
	local ics_new = slt2.render(assert(self:template_ics()), {self=self, broadcasts=broadcasts})
	return io.write_if_changed(ics_file, ics_new)
end
