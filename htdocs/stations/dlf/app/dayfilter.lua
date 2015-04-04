#!/usr/bin/env lua
--[[
-- Copyright (c) 2013-2015 Marcus Rohrmoser, https://github.com/mro/radio-pi
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


local now = os.date('%F')
local dateclip = os.date('%F', os.time() + (6*7-1)*24*60*60) -- look max 6 weeks ahead

local function check_total(d)
  return d <= dateclip
end
local function check_future(d)
  return d >= now and d <= dateclip
end
local function check_incremental(d)
  return d == now or d == os.date('%F', os.time() + (1)*24*60*60) or d == os.date('%F', os.time() + (7)*24*60*60)
end

local check_t = {
  ['--total']       = check_total,
  ['--future']      = check_future,
  ['--new']         = check_future,
  ['--incremental'] = check_incremental,
}
local check_f = check_t[arg[1]]

if not check_f then
  io.stderr:write([[
Read from stdin, filter days (ISO8601), write stdout.

  --new         >= today, max. 6 weeks future
  --total       all, max. 6 weeks future
  --future      >= today, max. 6 weeks future
  --incremental today, tomorrow, +1 week
]], '\n')
  os.exit(1)
end

for line in io.lines() do
  if check_f(line) then print(line) end
end
