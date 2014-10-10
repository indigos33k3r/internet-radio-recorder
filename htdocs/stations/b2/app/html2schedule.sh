#!/bin/sh

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

# TODO: check xsltproc for failure? http://stackoverflow.com/a/1550982
#
xsltproc --stringparam station_about_url "$station_rdf" --html --encoding utf-8 --novalid "$(basename "$0" .sh).xslt" "$tmp_file" 2>/dev/null \
| rapper --quiet --input rdfxml --output rdfxml-abbrev --input-uri "$scrape_url" --output-uri '.' - \
> ../cache/schedule.rdf \
&& touch -r "$tmp_file" ../cache/schedule.rdf

# rapper --input rdfxml --output turtle ../cache/schedule.rdf

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
roqet --exec "$sparql" --data ../cache/schedule.rdf --results csv --quiet | tail -n +2

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
