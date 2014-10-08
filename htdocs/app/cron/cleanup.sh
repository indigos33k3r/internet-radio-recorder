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

# delete all streamripper logs older than 10 days
/usr/bin/find enclosures -type f -mtime +10 -name "std*.log" -exec rm {} \; 1>> log/"$me".stdout.log 2>> log/"$me".stderr.log
# remove all empty dirs
# /usr/bin/find . -depth -type d -empty -exec rmdir {} \; 1>> log/"$me".stdout.log 2>> log/"$me".stderr.log
# fix access permissions
/usr/bin/find . -type d -exec chmod u+rwx,g+rx-w,o-rwx {} \; 1>> log/"$me".stdout.log 2>> log/"$me".stderr.log
