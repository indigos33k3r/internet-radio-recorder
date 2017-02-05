#!/bin/dash
#
# Copyright (c) 2013-2016 Marcus Rohrmoser, http://purl.mro.name/recorder
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

cd "$(dirname "${0}")"/../..
me="$(basename "${0}")"

stdout_log="log/${me}.stdout.log"
stderr_log="log/${me}.stderr.log"

start_time="$(/bin/date +'%s')"
echo "Start  $(/bin/date +'%FT%T')" | tee -a "${stderr_log}" 1>> "${stdout_log}"

version="0.2.6"
cmd="../bin/scrape-$(uname -s)-$(uname -m)-${version}"

[ -x "${cmd}" ] || { echo "Executable ${cmd} not found." 1>&2 && exit 1 ; }

${cmd} 2>> "${stderr_log}" \
| tee "log/${me}.stdout.dat" \
| app/broadcast-render.lua --luatables 2>> "${stderr_log}" \
1>> "${stdout_log}"

nice app/calendar.lua stations/* podcasts/* 1>> "${stdout_log}" 2>> "${stderr_log}"

finish_time="$(/bin/date +'%s')"
echo "Finish $(/bin/date +'%FT%T') dt=$((finish_time - start_time))s" | tee -a "${stderr_log}" 1>> "${stdout_log}"
