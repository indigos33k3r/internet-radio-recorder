--[[
-- Copyright (c) 2013-2016 Marcus Rohrmoser, http://purl.mro.name/recorder
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
Podcast = {}              -- methods table
Podcast_mt = { __index = Podcast }    -- metatable

function Podcast.each()
  if not Podcast._each then
    local ret = {}
    for pc_id in lfs.dir('podcasts') do
      ret[pc_id] = Podcast.from_id(pc_id)
    end
    Podcast._each = ret
  end
  return Podcast._each
end


function Podcast.from_id(id)
  local pc = nil
  if Podcast._each then pc = Podcast._each[id] end
  if not pc then
    local f = table.concat{'podcasts', '/', id, '/', 'app', '/', 'podcast.cfg'}
    local fh,msg = io.open(f,'r')
    if not fh then return nil,msg end
    local m,msg = loadstring('return ' .. assert(fh, msg):read('*a'))()
    fh:close()
    io.stderr:write('loading ', f, "\n")
    local ret = {
      id = id,
      title = assert(m.title, 'bo title'),
      subtitle = assert(m.subtitle, 'no subtitle'),
      episodes_to_keep = assert(m.episodes_to_keep, 'episodes'),
      match = assert(m.match, 'match'),
    }
    pc = setmetatable( ret, Podcast_mt )
    -- Podcast._each[id] = pc
  end
  return pc
end


function Podcast:url(type_)
  local t = {Recorder.base_url(), 'podcasts', '/', self.id}
  if type_ then
    table.insert(t, '.')
    table.insert(t, type_)
  end
  return table.concat(t):escape_url()
end


function Podcast:contains_broadcast(bc)
  return 'file' == lfs.attributes(table.concat{'podcasts', '/', self.id, '/', bc.id}, 'mode')
end


function Podcast:add_broadcast(bc)
  return io.write_if_changed(table.concat{'podcasts', '/', self.id, '/', bc.id}, '')
end


function Podcast:remove_broadcast(bc)
  return io.write_if_changed(table.concat{'podcasts', '/', self.id, '/', bc.id}, nil)
end


function Podcast:broadcasts(comparator,tmin,tmax)
  local tmp = {}
  local callback = function(file,t) table.insert( tmp, assert(Broadcast.from_file(file)) ) end
  local base = table.concat{'podcasts', '/', self.id}
  for station_id in lfs.dir(base) do
    local sta = table.concat{base, '/', station_id}
    if 'directory' == lfs.attributes(sta, 'mode') then
      lfs.files_between(sta, tmin, tmax, callback, true)
    end
  end
  if not comparator then
    comparator = function(a,b) return a:dtstart() < b:dtstart() end
  end
  table.sort(tmp, comparator)
  return tmp
end


local slt2 = require "slt2" -- http://github.com/henix/slt2

function Podcast:template_rss()
  local tmpl = self.template_rss_
  if not tmpl then
    local file = table.concat({ 'podcasts', assert(self.id), 'app', 'broadcasts.slt2.rss'}, '/')
    -- io.stderr:write('loading template \'', file, '\'\n')
    tmpl = slt2.loadfile(file)
    self.template_rss_ = tmpl
    io.stderr:write('loaded  ', file, '\n')
  end
  return tmpl
end


function Podcast:save_rss()
  local rss_file = table.concat{'podcasts', '/', assert(self.id), '/', 'broadcasts', '.rss'}
  local rss_new = slt2.render(assert(self:template_rss()), {podcast=self})
  return io.write_if_changed(rss_file, rss_new)
end


function Podcast:purge_outdated(dry_run)
  -- reverse, most recent first:
  local bcs = self:broadcasts(function(a,b) return a.id > b.id end, 0, os.time())
  local kept = 0
  for _,bc in ipairs(bcs) do
      if 'mp3' == bc:enclosure().state then
      -- io.stderr:write('purge_outdated ', bc.id, "\n")
      if kept < self.episodes_to_keep then
        kept = kept + 1
      else
        local ok,msg = bc:enclosure():purge(dry_run)
        if ok then
          io.stderr:write('purged ', bc.id, "\n")
        else
          io.stderr:write('purge failed ', bc.id, ' ', msg, "\n")
        end
      end
      elseif 'pending' == bc:enclosure().state then
        io.stderr:write('failed ', bc.id, "\n")
        if dry_run ~= true then
          bc:enclosure():unschedule('failed')
        end
    end
  end
end


function Podcast:template_ics()
  local tmpl = self.template_ics_
  if not tmpl then
    local file = table.concat({ 'podcasts', assert(self.id), 'app', 'broadcasts.slt2.ics'}, '/')
    -- io.stderr:write('loading template \'', file, '\'\n')
    tmpl = slt2.loadfile(file)
    self.template_ics_ = tmpl
    io.stderr:write('loaded  ', file, '\n')
  end
  return tmpl
end


function Podcast:save_ics(tmin,tmax)
  tmin = tmin or 0
  tmax = tmax or (100 * 365 * 24* 60 * 60)
  local ics_file = table.concat{'podcasts', '/', assert(self.id), '/', 'broadcasts', '.ics'}
  local ics_new = slt2.render(assert(self:template_ics()), {self=self, broadcasts=self:broadcasts(nil,tmin,tmax)})
  return io.write_if_changed(ics_file, ics_new)

end
