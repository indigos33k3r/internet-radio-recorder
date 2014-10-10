#!/bin/sh
#
# Copyright (c) 2013-2014 Marcus Rohrmoser, https://github.com/mro/radio-pi
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions
# and the following disclaimer.
# 
# 2. The software must not be used for military or intelligence or related purposes nor
# anything that's in conflict with human rights as declared in http://www.un.org/en/documents/udhr/ .
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
# THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#

curl --version      >/dev/null || { echo "sorry, need it." && exit 1; }
xsltproc --version  >/dev/null || { echo "sorry, need it." && exit 1; }
rapper --version    >/dev/null || { echo "consider $ brew install raptor" && exit 1; }
roqet --version     >/dev/null || { echo "consider $ brew install rasqal" && exit 1; }

cd "$(dirname "$0")"

local_base_uri='http://rec.mro.name/stations/b2/'
station_rdf="../about.rdf"

#####################################################################
# create station rdf
#
rapper --quiet --input turtle --output rdfxml-abbrev --input-uri "$local_base_uri" --output-uri . ../about.ttl \
> "$station_rdf" || { echo "Couldn't create station rdf." && exit 2; }

#####################################################################
# get scrape url from station rdf
#
scrape_url=$(xsltproc --encoding utf-8 rdf2base_url.xslt "$station_rdf")
if [ "$scrape_url" = "" ] ; then
   echo -e "Couldn't extract program base url from\n$(ls -l $(pwd)/../about.rdf)" 1>&2
   exit 2
fi

#####################################################################
# scrape schedule page
#
tmp_file=../cache/index.html
if [ ! -f "$tmp_file" ] ; then
  curl --create-dirs --time-cond "$tmp_file" --output "$tmp_file" --remote-time --url "$scrape_url"
fi

xsltproc --stringparam station_about_url "$station_rdf" --html --encoding utf-8 --novalid --output ../cache/schedule.rdf.raw "$(basename "$0" .sh).xslt" "$tmp_file" 2>/dev/null
if [ $? -ne 0 ] ; then
  cat 1>&2 <<HERE
Failed to run
  $ xsltproc --stringparam station_about_url "$station_rdf" --html --encoding utf-8 --novalid "$(basename "$0" .sh).xslt" "$tmp_file"
HERE
  exit 2
fi
rapper --quiet --input rdfxml --output rdfxml-abbrev --input-uri "$scrape_url" --output-uri '.' ../cache/schedule.rdf.raw \
> ../cache/schedule.rdf \
&& ../cache/schedule.rdf.raw \
&& rm touch -r "$tmp_file" ../cache/schedule.rdf

rapper --input rdfxml --output turtle ../cache/schedule.rdf

sparql=$(cat <<SETVAR
# http://tldp.org/LDP/abs/html/here-docs.html
# http://www.xml.com/pub/a/2005/11/16/introducing-sparql-querying-semantic-web-tutorial.html?page=5
#
# list all broadcast urls
#
PREFIX dct: <http://purl.org/dc/terms/>
  SELECT ?date ?title
  WHERE {
    ?url
      dct:title ?title ;
      dct:date ?date .
  }
  ORDER BY ASC(?date)
SETVAR
)
# roqet --exec "$sparql" --data ../cache/schedule.rdf --results csv --quiet | tail -n +2

sparql=$(cat <<SETVAR
# http://tldp.org/LDP/abs/html/here-docs.html
# http://www.xml.com/pub/a/2005/11/16/introducing-sparql-querying-semantic-web-tutorial.html?page=5
#
# list all schedule overview urls
#
PREFIX dct: <http://purl.org/dc/terms/>
  SELECT ?url
  WHERE {
    ?url
      dct:language ?language ;
      dct:date ?date .
  }
  ORDER BY DESC(?date)
SETVAR
)
# roqet --exec "$sparql" --data ../cache/schedule.rdf --results csv --quiet | tail -n +2
