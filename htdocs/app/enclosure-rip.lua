#!/usr/bin/env lua
--[[
-- Copyright (c) 2013-2014 Marcus Rohrmoser, https://github.com/mro/radio-pi
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
if os.getenv('HTTP_HOST') then
  io.write('HTTP/1.1 400 Bad Request', '\n')
  io.write('Content-Type: text/plain', '\n')
  io.write('Server: RadioPi 2013/lua', '\n')
  io.write('\n', 'I\'m not supposed to be run as cgi')
  io.write('\n')
  io.flush()
  os.exit(1)
end


-- ensure Recorder.lua (next to this file) is found:
package.path = arg[0]:gsub("/[^/]+/?$", '') .. "/?.lua;" .. package.path
require'Recorder'
Recorder.chdir2app_root( arg[0] )
local psx = require'posix'

if arg[1] == nil or arg[1] == '-?' or arg[1] == '-h'or arg[1] == '--help' then
  io.write([[streamripper convenience wrapper and watchdog a.k.a. blocking rip.

Usage:
  $ app/enclosure-rip.lua [--dry-run] enclosures/b2/2013/01/20/1405\ musikWelt.xml

]])
  os.exit(0)
end

--- Sorted pairs iterator.
--
-- http://www.lua.org/pil/19.3.html
function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0         -- iterator state
  local iter = function()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end


--- figure out if streamripper as started by myself is already running
-- 
-- TODO: mask single quotes
-- @return true/false
function Enclosure:is_ripping_ps()
  local ps = assert(io.popen('ps ux'), "Cannot call 'ps ux'")
  local pat = table.concat{'/streamripper', ".* %-d '([^']*/", self.id, ")' %-D '%.%./"}
  for line in ps:lines() do
    local hit,_ = line:match(pat)
    if nil ~= hit then return true end
  end
  ps:close()
  return false
end


function Enclosure:is_ripping()
  -- read pid from .ripping
  local pidfile = io.open(self:filename('ripping'), 'r')
  if not pidfile then return false end
  local pid = pidfile:read('*a')
  pidfile:close()
  if not pid then return false end
  if not psx.kill(pid, 0) then return false end
  -- that's a bit optimistic - should we check more thoroughly?
  -- maybe check timestamp of ripping mp3?
  -- look for streamripper child process?
  return true
end


function Enclosure:dir_mp3_temp()
  return self:filename()
end


function Enclosure:is_due(t)
  if not t then t = os.time() end
  if t < assert(assert(self.broadcast):dtstart()) - 10*60 then return false,'not due yet' end
  if t > assert(self.broadcast:dtend()) then return false,'already past' end
  return true
end


--- launch streamripper
-- 
-- renames .pending in .ripping and leaves a bunch of mp3s in ./incomplete
-- 
-- @return true
function Enclosure:run_streamripper(dry_run)
  if not dry_run then
    assert(mkdir_recursive(self:dir_mp3_temp()), "couldn't create dir '" .. self:dir_mp3_temp() .. "'")
  end
  local t_start = assert(self.broadcast:dtstart())
  local t_end = assert(self.broadcast:dtend())
  local stream_url = assert(self.broadcast:station().stream_url, 'stream url not found')
--  local dir = assert(self.dir, 'dir not found')
  local _,_,file = self.id:find('/([^/]+)$')

  local rip_head = -3 -- add to mp3
  local rip_tail = 15 -- add to mp3
  local rip_post = 5  -- keep streamripper running post recording
  while os.time() < t_end do
    io.stderr:write("starting rip ", self.id, " until ", os.date('%Y-%m-%d %H:%M:%S', t_end + rip_tail), "\n")
    local params_unsafe = {
      '/usr/bin/env','streamripper',
      stream_url,
      '-t',
      '-l', math.max(0, os.difftime(t_end, os.time()) + rip_tail + rip_post),
      '-u', 'iTunes/11.0.1 (Macintosh; OS X 10.7.5) AppleWebKit/534.57.7',
      '-s',             -- Don´t create a directory for each stream
      '-d', self:dir_mp3_temp(),    -- The destination directory
      '-D', '../' .. assert(file),  -- file to create
      '-o', 'version',
      '-E', 'app/streamripper-injector.lua ' .. t_start + rip_head .. ' ' .. t_end + rip_tail,
      '--codeset-filesys=UTF-8',
      '--codeset-id3=UTF-8',
      '--codeset-metadata=UTF-8',
      '--codeset-relay=UTF-8',
    }
    local params = escape_cmdline(params_unsafe)
--    table.insert(params, '1>>')
--    table.insert(params, (self:dir_mp3_temp() .. '/stdout.log'):escape_cmdline() )
--    table.insert(params, '2>>')
--    table.insert(params, (self:dir_mp3_temp() .. '/stderr.log'):escape_cmdline() )
    io.stderr:write('$ ', table.concat(params, ' '), "\n")
    if dry_run then
      return true
    else
      local ret = os.execute(table.concat(params, ' '))
      io.stderr:write('streamripper result ', ret, "\n")
    end
  end
  os.execute('find ' .. self:dir_mp3_temp():escape_cmdline() .. ' -type f -exec ls -l {} \\; 1>> ' .. (self:dir_mp3_temp() .. '/stdout.log'):escape_cmdline())
  return true
end

--- consolidate mp3 snippets from ./incomplete into one mp3 file.
-- 
-- uses 'cat' to concatenate the mp3s into .ripping and renames into .mp3.
-- 
-- removes ./incomplete, but leaves stdout.log and stderr.log.
-- 
-- @return -
function Enclosure:consolidate_mp3(dry_run)
  if dry_run then
    io.write('dry-run ', 'consolidate_mp3 ', self:dir_mp3_temp(), "\n")
    return true
  else
    local tmp_dir = self:dir_mp3_temp()
    -- pick up mp3 snippets (relative) file names into a unsorted table
    local mp3s_unsorted = {}
    local mp3_dir = table.concat({tmp_dir, 'incomplete'}, '/')
    for mp3_file in lfs.dir(mp3_dir) do
      -- print(mp3_file)
      local i1,i2,s = mp3_file:find('artist %- title(.*)%.mp3')
      if i1 then
        if s == '' then s = 10000
        else s = tonumber(s:sub(3,-2)) end
        mp3s_unsorted[s] = mp3_file
      elseif mp3_file ~= '.' and mp3_file ~= '..' then
        -- remove pre- + post recordings
        assert(os.remove(table.concat{mp3_dir, '/', mp3_file}))
      end
    end
  
    -- sort mp3 snippet (relative) file names
    local mp3s_sorted = {}
    for i,f in pairsByKeys(mp3s_unsorted) do table.insert(mp3s_sorted, f) end
    mp3s_unsorted = nil
  
    -- synth cat command to write mp3 snippets into .ripping file (sic!)
    local cat_cmd = {}
    table.insert(cat_cmd, "cat \\\n")
    for i,f in ipairs(mp3s_sorted) do
      table.insert(cat_cmd, '  ')
      table.insert(cat_cmd, mp3_dir:escape_cmdline())
      table.insert(cat_cmd, '/')
      table.insert(cat_cmd, f:escape_cmdline())
      table.insert(cat_cmd, "\\\n")
    end
    table.insert(cat_cmd, '  > ')
    table.insert(cat_cmd, tmp_dir:escape_cmdline())
    table.insert(cat_cmd, '.ripping')
    io.stderr:write(table.concat(cat_cmd), "\n")
    assert( 0 == os.execute(table.concat(cat_cmd)), 'failed to concatenate mp3s')
    cat_cmd = nil
  
    -- remove now concatenated mp3s
    for i,f in ipairs(mp3s_sorted) do
      assert( os.remove(table.concat{mp3_dir, '/', f}) )
    end
    mp3s_sorted = nil
    -- clean up 'incomplete' dir
    assert( os.remove(mp3_dir) )
    -- rename .ripping into .mp3
    assert( os.rename(self:filename('ripping'), self:filename('mp3')) )
    return true
  end
end


function Enclosure:id3tag_mp3(dry_run)
  local cmd = table.concat{'nice bundle exec app/enclosure-tag.rb ', self:filename('mp3'):escape_cmdline()}
  if dry_run then
    io.write('dry-run ', cmd, "\n")
    return true
  else
    -- io.stderr:write(cmd, "\n")
    return os.execute(cmd)
  end
end


local dry_run = arg[1] == '--dry-run'
local enc = nil
if dry_run then
  enc = assert(Broadcast.from_file( arg[2] ), "can't use broadcast " ..  arg[2]):enclosure()
else
  enc = assert(Broadcast.from_file( arg[1] ), "can't use broadcast " ..  arg[1]):enclosure()
end

if enc:is_ripping() then
  io.write("already ripping '", enc.id, "'", "\n")
  os.exit(1)
end
if not enc:is_due() then
  io.write("not due '", enc.id, "'", "\n")
  if not dry_run then os.exit(2) end
end

assert( 'pending' == enc.state or 'ripping' == enc.state, "enclosure '" ..  enc.id .. "' isn't pending nor ripping.")
assert( not enc:is_ripping(), "broadcast '" ..  enc.id .. "' is already recording.")
assert( dry_run or enc:is_due(), "broadcast '" .. enc.id .. "' isn't due.")

if not dry_run then
  -- remove pending and write ripping with pid
  io.write_if_changed(enc:filename('pending'), nil)
  assert(io.write_if_changed(enc:filename('ripping'), psx.getpid('pid')))
end
assert( enc:run_streamripper(dry_run) )
assert( enc:consolidate_mp3(dry_run) )

-- id3tag
pcall( enc:id3tag_mp3(dry_run ) )

for _,p in pairs(enc.broadcast:podcasts()) do
  p:purge_outdated(dry_run)
  p:save_rss()
end
