#!/bin/sh
cd "$(dirname "$0")"

#  Copyright (c) 2013-2015 Marcus Rohrmoser, https://github.com/mro/radio-pi
# 
#  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
#  associated documentation files (the "Software"), to deal in the Software without restriction,
#  including without limitation the rights to use, copy, modify, merge, publish, distribute,
#  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
# 
#  The above copyright notice and this permission notice shall be included in all copies or
#  substantial portions of the Software.
# 
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
#  NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
#  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# 
#  MIT License http://opensource.org/licenses/MIT


# Optional: get program url from station.cfg
program_url="http://www.deutschlandfunk.de/programmvorschau.281.de.html"

myself="$(basename "$0")"

cmd="$1" ; shift
tmp_prefix="/tmp/$(basename "$0")"
tmp_suffix="lua"
tmp_file="$tmp_prefix-$$.$tmp_suffix"
recursion_blocker="broadcasts"

if [ "$cmd" = "--total" ] || [ "$cmd" = "--new" ] || [ "$cmd" = "--future" ] || [ "$cmd" = "--incremental" ] ; then
  if [ "$1" = "" ] ; then
    # called WITHOUT day list
    echo "scrape schedule..." 1>&2
    rm "$tmp_prefix-"*".$tmp_suffix" 2> /dev/null
    # echo xsltproc --html days-dlf.xslt "$program_url"
    xsltproc --html days-dlf.xslt "$program_url" 2>/dev/null \
     | ./dayfilter.lua "$cmd" \
     | xargs -n 1 -P 20 "./$myself" "$cmd" "$recursion_blocker"
    cat "$tmp_prefix-"*".$tmp_suffix"
    rm "$tmp_prefix-"*".$tmp_suffix" 2> /dev/null
  else
    # called WITH day list
    echo "./$myself $cmd $@" 1>&2
    if [ "$1" = "$recursion_blocker" ]
    then
      shift
      rm "$tmp_file" 2> /dev/null
      while [ "$1" != "" ] ; do
        tmp_file="$tmp_prefix-$1.$tmp_suffix"
        year=$(echo $1 | cut -d "-" -f 1)
        mon=$(echo $1 | cut -d "-" -f 2 | sed 's/^[0]*//') # http://www.unixcl.com/2010/04/remove-leading-zero-from-line-awk-sed.html
        day=$(echo $1 | cut -d "-" -f 3 | sed 's/^[0]*//')
        echo xsltproc --html broadcasts2rdf-dlf.xslt "$program_url?drbm:date=$day.$mon.$year" 1>&2
        xsltproc --html broadcasts2rdf-dlf.xslt "$program_url?drbm:date=$day.$mon.$year" 2>/dev/null \
         | xsltproc rdf2lua.xslt - 2>/dev/null \
         | ./broadcast-amend.lua "$cmd" \
         >> "$tmp_file"
        echo "scraped $1" 1>&2
        shift
      done
    else
      echo "ouch" 1>&2
      exit 1
    fi
  fi
  exit 0
fi

cat 1>&2 <<InputComesFromHERE
Rescrape broadcasts.

  --new         all missing broadcasts (actually: all future broadcasts)
  --total       all broadcasts
  --future      all future broadcasts
  --incremental next hour, next hour tomorrow, +1 week (actually: all today, tomorrow, +1 week)

InputComesFromHERE

exit 0
