#!/bin/sh

for rdf in "$(dirname "${0}")"/../htdocs/stations/*/about.rdf
do
  # ls -l "${rdf}"
  # http://stackoverflow.com/a/8266075
  # /bin/echo -e "setns foaf=http://xmlns.com/foaf/0.1/\nsetns rdf=http://www.w3.org/1999/02/22-rdf-syntax-ns#\nxpath /rdf:RDF/rdf:Description['.'=@rdf:about]/foaf:logo/@rdf:resource" | xmllint --shell "${rdf}"

  # as long as there's no & in url:
  logo_url="$(fgrep 'foaf:logo' "${rdf}" | head -n 1 | cut -d '"' -f 2)"
  # echo "${logo_url}"
  curl --silent --location --output "$(dirname "${rdf}")/app/logo.svg" "${logo_url}"
done

ls -Al "$(dirname "${0}")"/../htdocs/stations/*/app/logo.svg
