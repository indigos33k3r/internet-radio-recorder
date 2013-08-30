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


local function meta_key_to_lua(k)
  return k:gsub('%.', '_')
end


function string:to_filename()
  local replace = {
    ['–'] = '-',
    ['/'] = '-',
    ["\t"]  = ' ',
    ["\n"]  = ' ',
  }
  local escape = {
  }
  local subf = function(s)
    return replace[s] or escape[s] or s
  end
  return self:gsub('.', subf)
end


-------------------------------------------------------------------------------
-- Broadcast ------------------------------------------------------------------
-------------------------------------------------------------------------------

require'Station'
require'Podcast'
require'Enclosure'

-- http://nova-fusion.com/2011/06/30/lua-metatables-tutorial/
-- http://lua-users.org/wiki/LuaClassesWithMetatable
Broadcast = {}              -- methods table
Broadcast_mt = { __index = Broadcast }  -- metatable

function Broadcast_mt.__eq(a,b)
  return a.id == b.id
end

-- compare acc. time, ignore dst switch.
function Broadcast_mt.__le(a,b)
  if     a.year  < b.year  then return true
  elseif a.year  > b.year  then return false
  elseif a.month < b.month then return true
  elseif a.month > b.month then return false
  elseif a.day   < b.day   then return true
  elseif a.day   > b.day   then return false
  elseif a.hour  < b.hour  then return true
  elseif a.hour  > b.hour  then return false
  elseif a.min   < b.min   then return true
  elseif a.min   > b.min   then return false
  elseif a.sec   < b.sec   then return true
  elseif a.sec   > b.sec   then return false
  else return a.id <= b.id end
end

function Broadcast_mt.__lt(a,b)
  return a <= b and not (b <= a)
end

function Broadcast_mt.__tostring(self)
  return self.id
end


local function factory(ret)
  local file = assert(ret._title):to_filename()
  local t = os.time(ret)
  ret.dir = table.concat{assert(ret._station).id, '/', os.date('%Y/%m/%d', t)}
  ret.id  = table.concat{ret.dir, '/', os.date('%H%M', t), ' ',  file}
  return setmetatable( ret, Broadcast_mt )
end


function Broadcast.from_meta(meta)
  local pbmi = {
    DC_scheme           = assert( meta.DC_scheme ),
    DC_language         = assert( meta.DC_language ),
    DC_title            = assert( meta.DC_title ),
    DC_title_series     = meta.DC_title_series,
    DC_title_episode    = meta.DC_title_episode,
    DC_format_timestart = assert( meta.DC_format_timestart ),
    DC_format_timeend   = assert( meta.DC_format_timeend ),
    DC_format_duration  = assert( meta.DC_format_duration ),
    DC_image            = meta.DC_image,
    DC_description      = assert( meta.DC_description ),
    DC_author           = meta.DC_author,
    DC_creator          = meta.DC_creator,
    DC_publisher        = meta.DC_publisher,
    DC_copyright        = assert( meta.DC_copyright ),
    DC_source           = assert( meta.DC_source ),
  }
  local ret = os.date('*t', assert(parse_iso8601(meta.DC_format_timestart, 'missing key \'DC_format_timestart\'')))
  ret._station = assert(Station.from_id(meta.station), 'missing key \'station\'')
  ret._dtend  = assert(parse_iso8601(meta.DC_format_timeend, 'missing key \'DC_format_timeend\''))
  ret._title  = assert(meta.title)
  ret._pbmi   = pbmi
  return factory(ret)
end


function Broadcast.from_id(f)
  local ok,_,station,year,month,day,hour,min,title = f:find('([^/]+)/(%d%d%d%d)/(%d%d)/(%d%d)/(%d%d)(%d%d)%s(.+)$')
  if not ok then return nil end
  local ret = os.date('*t', os.time{year=year,month=month,day=day,hour=hour,min=min})
  ret._station = assert(Station.from_id(station), 'missing key \'station\': ' .. f)
  ret._title  = assert(title, 'missing title')
  return factory(ret)
end


function Broadcast.from_file(f)
  local ok,_,id,ext = f:find('(.+)(%.[^%.]+)$')
  if not ok then return nil end
  return Broadcast.from_id(id)
end


function Broadcast:title()
  return assert(self._title)
end


function Broadcast:station()
  return assert(self._station)
end


function Broadcast:dtstart()
  if not self._dtstart then
    self._dtstart = assert(parse_iso8601(self:pbmi().DC_format_timestart))
  end
  return self._dtstart
end


function Broadcast:dtend()
  if not self._dtend then
    self._dtend = assert(parse_iso8601(self:pbmi().DC_format_timeend))
  end
  return self._dtend
end


function Broadcast:is_past(now)
  if now == nil then now = os.time() end
  if os.time(self) < now then
    -- already started, but still running?
    if self:dtend() < now then
      -- io.stderr:write('I\'m past: ', self.id, "\n")
      return true
    end
  end
  return false
end


-- return table w. <meta> plus xml source
-- TODO: sanity check found meta!
local function broadcast_meta_from_xml(xml_file)
  local metas,xml_old,file = {},nil,io.open(xml_file, 'r')
  if file == nil then return nil,nil,xml_file end
  local xml_old = file:read('*a')
  file:close()
  for v,k in xml_old:gmatch('<meta%s+content=\'([^\']*)\'%s+name=\'(DC%.[^\']+)\'%s*/?>') do
    local k,v = k:unescape_xml_text(),v:unescape_xml_text()
    metas[ meta_key_to_lua(k) ] = v
  end
  return metas,xml_old,xml_file
end


function Broadcast:filename(state)
  local t = {'stations', '/', self.id}
  if state then
    table.insert(t, '.')
    table.insert(t, state)
  end
  return table.concat(t)
end


function Broadcast:url(type_)
  return table.concat{Recorder.base_url(), self:filename(type_)}:escape_url()
end

-- accessor to Dublin Core PBMI http://dcpapers.dublincore.org/pubs/article/view/749
function Broadcast:pbmi()
  if not self._pbmi then
    self._pbmi,_,file = broadcast_meta_from_xml(self:filename('xml'))
    assert(self._pbmi,'Couldn\'t load pbmi from ' .. file)
  end
  return assert(self._pbmi, 'lazy load failure.')
end


function Broadcast:enclosure()
  if not self._enclosure then
    self._enclosure = Enclosure.from_broadcast(self)
  end
  return self._enclosure
end


function Broadcast:add_podcast(pc)
  self:podcasts()[pc.id] = pc
end


function Broadcast:remove_podcast(pc)
  self:podcasts()[pc.id] = nil
  pc:remove_broadcast(self)
end


function Broadcast:podcasts()
  if not self._podcasts then
    local ret = {}
    for pi_id,pc in pairs(Podcast.each()) do
      if pc:contains_broadcast(self) then
        ret[pi_id] = pc
      end
      -- check presence ?
      -- evtl. check match ?
      -- add to podcast ?
      -- add to list ?
    end
    self._podcasts = ret
  end
  return self._podcasts
end


function Broadcast:match_podcasts()
  for pc_id,pc in pairs( Podcast.each() ) do
    local ok,match = pcall(assert(pc.match, 'match'), assert(self:pbmi(), 'pbmi'))
    if ok and match then
      self:podcasts()[pc_id] = pc
    end
  end
end


-- find first one smaller or equal dtstart
function Broadcast:prev_sibling()
  return self:station():broadcast_now(self:dtstart()-1,true,false)
end


-- find first one bigger or equal dtend
function Broadcast:next_sibling()
  return self:station():broadcast_now(self:dtend(),true,true)
end


function Broadcast:monopolize(dry_run)
  local callb = function( path )
    local other = Broadcast.from_file( path )
    if other ~= nil and other ~= self then other:remove(dry_run) end
    return false
  end
  lfs.files_between(table.concat({'stations',self:station().id},'/'), self:dtstart(), self:dtend()-0.1, callb, true)
end


function Broadcast:log_change(msg)
  io.stderr:write(string.format("%-7s %s\n",msg,self.id))
  if 'unchang' == msg then return end
  local f,_ = io.open('stations/change.ttl', 'a+')
  if f then
    f:write("<", self.id, ".xml> <http://purl.org/dc/terms/modified> \"", os.date("!%Y-%m-%dT%H:%M:%SZ"), "\" .\n")
    f:close()
  end
end


function Broadcast:remove(dry_run)
  self:log_change('delete')
  if dry_run then return end
  self:enclosure():unschedule()
  for _,pc in pairs(self:podcasts()) do
    pc:remove_broadcast(self)
  end
  io.write_if_changed(self:filename('json'), nil)
  io.write_if_changed(self:filename('xml'), nil)
end

function Broadcast:save_xml()
  -- TODO check time overlaps?
  local xml = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<?xml-stylesheet type="text/xsl" href="../../../app/broadcast2html.xslt"?>',
    '<!-- Dublin Core PBMI http://dcpapers.dublincore.org/pubs/article/view/749 -->',
    '<!-- not: Ontology for Media Resources 1.0 http://www.w3.org/TR/mediaont-10/ -->',
    '<!-- not: EBU http://tech.ebu.ch/lang/en/MetadataEbuCore -->',
    '<broadcast xml:lang="de" xmlns="../../../../../assets/2013/radio-pi.rdf">',
  }
  local row = {'    ', '<meta content=\'', self.id:escape_xml_attribute(), '\' name=\'', 'DC.identifier', '\'/>'}
  table.insert( xml, table.concat(row) )
  for _,k in ipairs({
    'DC.scheme', 'DC.language', 'DC.title', 'DC.title.series', 'DC.title.episode',
    'DC.format.timestart', 'DC.format.timeend', 'DC.format.duration', 'DC.image',
    'DC.description', 'DC.author', 'DC.publisher', 'DC.creator', 'DC.copyright', 'DC.source',
  }) do
    local v = self:pbmi()[ meta_key_to_lua(k) ]
    if not v then v = '' end
    local row = {'    ', '<meta content=\'', v:escape_xml_attribute(), '\' name=\'', k, '\'/>'}
    table.insert( xml, table.concat(row) )
  end
  table.insert( xml, '</broadcast>' )
  return io.write_if_changed(self:filename('xml'), table.concat(xml,"\n"))
end


function Broadcast:save_podcast_json()
  -- io.stderr:write('to_podcast_json()', "\n")
  local pc_ids = {}
  for pc_id,pc in pairs( self:podcasts() ) do
    pc:add_broadcast(self)
    table.insert(pc_ids, pc.id)
  end
  local json = nil
  if #pc_ids > 0 then
    json = table.concat{'{ "podcasts":[{"name":"', table.concat(pc_ids,'"},{"name":"'), '"}] }'}
  end
  return io.write_if_changed(self:filename('json'), json)
end


function Broadcast:save_schedule()
  for _,_ in pairs(self:podcasts()) do
    -- no way to tell count of a hash - so we start to iterate and return after first
    return self:enclosure():schedule()
  end
  return self:enclosure():unschedule()
end


function Broadcast:save()
  self:monopolize()
  -- broadcast xml
  local file,msg,err = self:save_xml()
  self:log_change(msg)
  -- podcast membership
  for _,pc in pairs(self:podcasts()) do
    pc:add_broadcast(self)
  end
  self:save_podcast_json()
  -- schedule
  local at_job,cmd = self:save_schedule()
  -- if at_job then io.stderr:write('at job  ', at_job, ' ', cmd, "\n") end
  return file,msg,err
end
