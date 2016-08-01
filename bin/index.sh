#!/bin/sh
#
# Copyright (c) 2015 Marcus Rohrmoser, http://purl.mro.name/recorder
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
#
#

#
# generate a index.xml for either
# - the accoding day-directories (commandline params) or
# - all day-directories
# by aggregating all broadcast xml files.
#

xmllint --version 2>/dev/null || { echo "Please install xmllint" && exit 1; }

cwd="$(pwd)"

cd "$(dirname "${0}")" && script_dir="$(pwd)"
script_path="${script_dir}/$(basename "${0}")"

cd "${cwd}" && cd "$(dirname "${0}")/../htdocs/stations" || { echo "foo" 1>&2 && exit 1; }
base_dir="$(pwd)"

recursion_blocker="recursion_blocker"

if [ "" = "${1}" ] ; then
  ls -fds */????/??/?? | sort | xargs -P 1 "${script_path}" "${recursion_blocker}"
else
  if [ "${recursion_blocker}" = "${1}" ] ; then shift ; fi
  while [ "" != "${1}" ]
  do
    cd "${cwd}/${1}"
    if [ 0 -eq $? ] ; then
      prefix="$(pwd | egrep -hoe '[^/]+/[0-9]{4}/[0-9]{2}/[0-9]{2}$')"
      date="$(pwd | egrep -hoe '[0-9]{4}/[0-9]{2}/[0-9]{2}$' | tr '/' '-')"

      dst="index.xml"
      # http://stackoverflow.com/a/7046926
      cat > "${dst}"~ <<END_OF_XML_PREAMBLE
<?xml-stylesheet type='text/xsl' href='../../../app/broadcasts2html.xslt'?>
<!-- unorthodox relative namespace to enable http://www.w3.org/TR/grddl-tests/#sq2 without a central server -->
<broadcasts date='${date}' xmlns='../../../../../assets/2013/radio-pi.rdf'>
END_OF_XML_PREAMBLE
      for xml in ????\ *.xml
      do
        xmllint --nowarning --noout "${xml}" || { echo "not well-formed: ${xml}" 1>&2 && continue ; }
        # timezone fix each xml in place?
        grep -hoe "^\s*<broadcast\s[^>]*" "${xml}" >> "${dst}"~               # start tag without closing >
        echo " modified='$(date --reference="${xml}" +\%F'T'\%T\%:z)'>" >> "${dst}"~  # additional attribute: file modification time
        grep 'DC.identifier' "${xml}" 1>/dev/null 2>/dev/null || {          # amend identifier if missing.
          echo "  <meta content='${prefix}/$(basename "${xml}" .xml | sed -e "s/&/\&amp;/g" -e "s/'/\&apos;/g")' name='DC.identifier'/>" >> "${dst}"~
        }
        grep -v '^<!-- ' "${xml}" | grep -v "<meta content='' " | tail -n +4 >> "${dst}"~ # rest of the broadcast xml file
      done
      echo "</broadcasts>" >> "${dst}"~

      # timezone fix resulting xml - add colon in case
      sed --in-place --posix --regexp-extended --expression 's/([0-9]{4}-[0-9]{2}-[0-9]{2})[T ]([0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2})00/\1T\2:00/g' "${dst}"~

      printf "%s/" "${1}" 1>&2
      xmllint --nowarning --nsclean --format --encode "UTF-8" --relaxng "../../../../../app/pbmi2003-recmod2012/broadcast.rng" --output "${dst}" "${dst}"~ && rm "${dst}"~
      if [ 0 -eq $? ] ; then
        gzip --best "${dst}"
        echo "${1}/${dst}.gz"
      else
        rm "${dst}"
      fi
    fi
    shift
  done
fi
