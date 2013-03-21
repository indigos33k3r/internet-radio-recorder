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

require 'lat'

-- http://nova-fusion.com/2011/06/30/lua-metatables-tutorial/
-- http://lua-users.org/wiki/LuaClassesWithMetatable
Enclosure = {}							-- methods table
Enclosure_mt = { __index = Enclosure }	-- metatable


function Enclosure.from_broadcast(bc)
	local tbl = {
		broadcast = assert(bc),
		id = assert(bc.id),
		states = {},
		state = 'none',
	}
	local _dir = dir_name(tbl.id)
	if 'directory' == lfs.attributes('enclosures/' .. _dir, 'mode') then
		local states_available = {'pending', 'ripping', 'failed', 'mp3', 'purged'}
		for f in lfs.dir('enclosures/' .. _dir) do
			local tmp = table.concat{_dir, '/', f}
			local state = nil
			for _,stat in ipairs(states_available) do
				if tmp == table.concat{tbl.id, '.', stat} then
					if tbl.state == 'none'
					then tbl.state = stat
					else tbl.state = nil
					end
					tbl.states[stat] = true
				end
			end
		end
	end
	return setmetatable( tbl, Enclosure_mt )
end


function Enclosure:filename(state)
	local t = {'enclosures', '/', self.id}
	if state then
		table.insert(t, '.')
		table.insert(t, state)
	end
	return table.concat(t)
end


function Enclosure:url(type_)
	return table.concat{Recorder.base_url(), self:filename(type_)}:escape_url()
end


-- internal helper
function Enclosure:at_jobnum()
	local pending = self:filename('pending')
	local f_pending = io.open(pending, 'r')
	if not f_pending then
		return nil,pending
	end
	local at_job = tonumber(f_pending:read('*a'))
	f_pending:close()
	local at_job_real = os.atq(at_job)
	-- verify - query 'at' for mere EXISTENCE of such a job as a hint:
	if at_job and at_job ~= at_job_real then
		io.stderr:write('warning ', 'inconsistent job numbers. Expected #', tonumber(at_job), ' found #', tonumber(at_job_real), '. repairing...', "\n")
		io.write_if_changed(pending, at_job_real)
		return at_job_real,pending
	end
	return at_job,pending
end


-- safe to call repeatedly
function Enclosure:schedule()
	if self.broadcast:is_past() then
		-- evtl. check + cleanup?
		return nil,'is past'
	end
	local at_job,pending = self:at_jobnum()
	if not at_job then
		local params_unsafe = {assert(Recorder.app_root) .. '/app/enclosure-rip.lua', self.broadcast:filename('xml')}
		local cmd = table.concat(escape_cmdline(params_unsafe), ' ')
		local at_time = math.max(self.broadcast:dtstart() - 90, os.time() + 2)
		at_job = os.at(at_time, cmd, 'c')
		io.write_if_changed(pending, at_job)
		return at_job,cmd
	else
		return at_job,'already there, check?'
	end
end


-- safe to call repeatedly
function Enclosure:unschedule(state)
	local at_job,pending = self:at_jobnum()
	if at_job then os.atrm(at_job) end
	io.write_if_changed(pending, nil)
	if pending and state then io.write_if_changed(self:filename(state), '') end
end


function Enclosure:purge(dry_run)
	if 'mp3' ~= self.state then return false,'not mp3' end
	-- TODO: check ALL podcasts if we're really to be deleted. Membership is quick but count expensive.
	-- io.stderr:write('purge ', self.id, "\n")
	if dry_run then return true,'dry_run' end
	os.remove( self:filename('mp3') )
	return io.write_if_changed(self:filename('purged'), '')
end


