#!/bin/sh

curl --version      >/dev/null || { echo "sorry, need it." && exit 1; }
xsltproc --version  >/dev/null || { echo "sorry, need it." && exit 1; }
rapper --version    >/dev/null || { echo "consider $ brew install raptor" && exit 1; }
roqet --version     >/dev/null || { echo "consider $ brew install rasqal" && exit 1; }

cd "$(dirname "$0")"

local_base_uri='http://.../stations/b2/'
station_rdf="../about.rdf"

#####################################################################
# create station rdf
#
rapper --quiet --input turtle --output rdfxml-abbrev --input-uri "$local_base_uri" --output-uri . ../about.ttl \
> "$station_rdf" || { echo "Couldn't create station rdf." && exit 2; }

#####################################################################
# get base program url from station rdf
#
program_base_url=$(xsltproc --encoding utf-8 rdf2base_url.xslt "$station_rdf")
if [ "$program_base_url" = "" ] ; then
   echo -e "Couldn't extract program base url from\n$(ls -l $(pwd)/../about.rdf)" 1>&2
   exit 2
fi

#####################################################################
# find all program urls to scrape.
#
tmp_file=../cache/index.html
if [ ! -f "$tmp_file" ] ; then
	curl --create-dirs --time-cond "$tmp_file" --output "$tmp_file" --remote-time --url "$program_base_url"
fi

xsltproc --html --encoding utf-8 --novalid "$(basename "$0" .sh).xslt" "$tmp_file" 2> /dev/null \
| rapper --quiet --input rdfxml --output rdfxml-abbrev --input-uri "$program_base_url" --output-uri '.' - \
> ../cache/dayurls.rdf \
&& touch -r "$tmp_file" ../cache/dayurls.rdf

#####################################################################
# scrape one day url for broadcasts
#
echo '' > ../cache/days.ttl
xsltproc --html --encoding utf-8 --novalid --stringparam station_about_url ../about.rdf day.xslt "$tmp_file" 2>/dev/null \
| rapper --input rdfxml --output turtle --input-uri "$program_base_url" --output-uri '.' - \
>> ../cache/days.ttl

cat ../cache/days.ttl
