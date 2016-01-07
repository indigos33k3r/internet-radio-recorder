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


-------------------------------------------------------------------------------
-- iso date time --------------------------------------------------------------
-------------------------------------------------------------------------------


--- Takes a timestamp in UTC and converts it to local time
local function utc2local(t_utc)
  local tzo = os.difftime(t_utc, os.time(os.date('!*t', t_utc)))
  return t_utc + tzo
end

-- TODO: apply proper date/time parsing: http://stackoverflow.com/questions/7911322/lua-iso-8601-datetime-parsing-pattern
function parse_iso8601(iso)
  if not iso then return nil,'nil' end
  local year,month,day,hour,minute,second,tzh,tzm = iso:match("(%d%d%d%d)-?(%d%d)-?(%d%d)[T ]?(%d%d):?(%d%d):?(%d%d)([+-]%d%d):?(%d%d)")
  if not year then return nil,'cannot parse \'' .. iso .. '\'' end
  -- is there a (sane) way of finding the (local) timezone if omitted?
  -- http://lua-users.org/wiki/TimeZone maybe?
  tzh = tonumber(assert(tzh))
  tzm = tonumber(tzm) or 0
  local sign = 1
  if tzh < 0 then sign = -1 end
  minute = tonumber(minute) - (tzh * 60 + sign * tzm)

  local date = {
    year    = tonumber(year),
    month   = tonumber(month),
    day     = tonumber(day),
    hour    = tonumber(hour),
    min     = minute,
    sec     = tonumber(second),
    isdst   = false,
  }
  -- normalise time to current local time:
  return utc2local(os.time(date))
end

-- http://stackoverflow.com/a/4105340
function parse_date_rfc1123(s,default_)
  if not s or '' == s then return default_ end
  local p = '%a+,%s+(%d+)%s+(%a+)%s+(%d+)%s+(%d+):(%d+):(%d+)%s+(%a+)'
  local day,month,year,hour,min,sec,tz = s:match(p)
  if not tz then return default_ end
  local MON={Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
  return os.time({tz=tz,day=day,month=MON[month],year=year,hour=hour,min=min,sec=sec,isdst=false})
end


-------------------------------------------------------------------------------
-- filesystem -----------------------------------------------------------------
-------------------------------------------------------------------------------


require 'luarocks.loader' -- http://www.luarocks.org/en/Using_LuaRocks
local lfs = require 'lfs' -- http://keplerproject.github.com/luafilesystem/examples.html

function dir_name(file_path)
  local _,_,parent = file_path:find("^(.*)/[^/]+/?$")
  return parent
end

function mkdir_recursive(dir)
  if 'directory' == lfs.attributes(dir,'mode') then return true end
  local parent = dir_name( dir )
  if parent and parent ~= dir then
    local ok,msg = mkdir_recursive(parent)
    if not ok then return ok,msg end
  end
  return lfs.mkdir(dir)
end

function io.write_if_changed(file, content, old)
  if old == nil then
    local old_f = io.open(file)
    if old_f then
      old = old_f:read('*a')
      old_f:close()
    end
  end
  if content == old then
    return file,'unchang'
  end
  if content == nil then
    os.remove(file)
    return file,'deleted'
  end
  mkdir_recursive(dir_name(file))
  local new_f,msg = io.open(file, 'w')
  if new_f then
    new_f:write(content)
    new_f:close()
    return file,'written'
  end
  return nil,'error ',msg
end


-------------------------------------------------------------------------------
-- http -----------------------------------------------------------------------
-------------------------------------------------------------------------------


function http_400_bad_request(...)
  io.write('HTTP/1.1 400 Bad Request', '\n')
  io.write('Content-Type: text/plain', '\n')
  -- http://www.w3.org/TR/CSP/#example-policies
  io.write("Content-Security-Policy: default-src 'none'", '\n')
  io.write('Server: RadioPi 2013/lua', '\n')
  io.write('\n')
  io.write(...)
  io.write('\n')
  io.flush()
  os.exit(0)
end

function http_304_unmodified(head)
  io.write('HTTP/1.1 304 unmodified', '\n')
  io.write('Server: RadioPi 2013/lua', '\n')
  for k,v in pairs(head) do io.write(k, ': ', v, '\n') end
  io.write('\n')
  io.flush()
end

function http_303_see_other(uri, msg, expires)
  io.write('HTTP/1.1 303 See Other', '\n')
  io.write('Content-Type: text/plain', '\n')
  -- http://www.w3.org/TR/CSP/#example-policies
  io.write("Content-Security-Policy: default-src 'none'; ", '\n')
  io.write('Server: RadioPi 2013/lua', '\n')
  if expires then
    io.write('Expires: ', expires, '\n')
  end
  io.write('Location: ', uri, '\n')
  io.write('\n')
  if msg then io.write(msg, '\n') end
  io.flush()
end

function http_200_ok(head,...)
  io.write('HTTP/1.1 200 ok', '\n')
  for k,v in pairs(head) do io.write(k, ': ', v, '\n') end
  -- http://www.w3.org/TR/CSP/#example-policies
  io.write("Content-Security-Policy: default-src 'none'; ", '\n')
  io.write('Server: RadioPi 2013/lua', '\n')
  io.write('\n')
  io.write(...)
  io.write('\n')
  io.flush()
end


-------------------------------------------------------------------------------
-- string escaping ------------------------------------------------------------
-------------------------------------------------------------------------------


function string:escape_cmdline()
  local tt = {
    ['\\'] = '\\\\',
    ['"'] = '\\"',
  }
  return table.concat{'"', self:gsub('["\\]', tt), '"'}
end


function escape_cmdline(params_unsafe)
  local ret = {}
  for _,p in ipairs(params_unsafe) do
    table.insert(ret, tostring(p):escape_cmdline())
  end
  return ret
end

-- http://lua-users.org/wiki/StringRecipes
function string:escape_url()
  return self:gsub("([^A-Za-z0-9_%./:-])", function(c)
    -- iTunes bails at +. if c == ' ' then return '+' end
    return string.format("%%%02x", string.byte(c))
  end)
end


-- http://lua-users.org/wiki/StringRecipes
function string:unescape_url()
  ret = self:gsub('+', ' ')
  ret = ret:gsub('%%(%x%x)', function(h) return string.char(tonumber(h,16)) end)
  return ret:gsub("\r\n", "\n")
end


function string:unescape_url_param()
  ret = self:gsub('%%(%x%x)', function(h) return string.char(tonumber(h,16)) end)
  return ret:gsub("\r\n", "\n")
end


function string:escape_xml()
  local tt = {
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;',
    ["'"] = '&apos;',
  }
  str = self:gsub('&', '&amp;')
  str = str:gsub('[<>"\']', tt)
  return str
end


function string:escape_xml_attribute()
  local tt = {
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;',
    ["'"] = '&apos;',
    ["\n"] = '&#10;',
  }
  return self:gsub('&', '&amp;'):gsub('[<>"\'\n]', tt)
end


function string:unescape_xml_text()
  -- http://www.w3.org/TR/2008/REC-xml-20081126/#sec-references
  local entities = {
    ['&amp;'] = '&',
    ['&lt;']  = '<',
    ['&gt;']  = '>',
    ['&apos;']  = '\'',
    ['&quot;']  = '"',
    ['&#10;'] = "\n",
  }
  local subf = function(s)
    return entities[s] or s:gsub('&#(%x%x);', function(h) return string.char(tonumber(h,16)) end)
  end
  return self:gsub('(&[^;]+;)', subf)
end


-------------------------------------------------------------------------------
-- table sorted pairs http://lua-users.org/wiki/SortedIteration ---------------
-------------------------------------------------------------------------------

--[[
Ordered table iterator, allow to iterate on the natural order of the keys of a
table.

Example:
]]
function __genOrderedIndex( t )
  local orderedIndex = {}
  for key in pairs(t) do
    table.insert( orderedIndex, key )
  end
  table.sort( orderedIndex )
  return orderedIndex
end

function orderedNext(t, state)
  -- Equivalent of the next function, but returns the keys in the alphabetic
  -- order. We use a temporary ordered key table that is stored in the
  -- table being iterated.
  key = nil
  --print("orderedNext: state = "..tostring(state) )
  if state == nil then
    -- the first time, generate the index
    t.__orderedIndex = __genOrderedIndex( t )
    key = t.__orderedIndex[1]
  else
    -- fetch the next value
    for i = 1,table.getn(t.__orderedIndex) do
      if t.__orderedIndex[i] == state then
        key = t.__orderedIndex[i+1]
      end
    end
  end

  if key then
    return key, t[key]
  end

  -- no more value to return, cleanup
  t.__orderedIndex = nil
  return
end

function orderedPairs(t)
  -- Equivalent of the pairs() function on tables. Allows to iterate
  -- in order
  return orderedNext, t, nil
end
