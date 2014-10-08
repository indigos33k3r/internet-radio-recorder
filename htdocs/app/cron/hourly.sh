#!/bin/dash
#
# Copyright (c) 2013-2014 Marcus Rohrmoser, https://github.com/mro/radio-pi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
# OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# MIT License http://opensource.org/licenses/MIT

cd "$(dirname "$0")"/../..
me="$(basename "$0")"

/bin/date 1>> log/"$me".stdout.log 2>> log/"$me".stderr.log
for scraper in stations/*/app/scraper.??
do
  case "$scraper" in
    *.rb)
      nice bundle exec $scraper --incremental 2>> log/"$me".stderr.log | app/broadcast-render.lua --stdin 1>> log/"$me".stdout.log 2>> log/"$me".stderr.log
    ;;
    *)
      nice $scraper --incremental 2>> log/"$me".stderr.log | app/broadcast-render.lua --stdin 1>> log/"$me".stdout.log 2>> log/"$me".stderr.log
    ;;
  esac
done

nice app/calendar.lua stations/* podcasts/* 1>> log/"$me".stdout.log 2>> log/"$me".stderr.log

/bin/date 1>> log/"$me".stdout.log
