#!/bin/sh
cd "$(dirname "$0")/../htdocs/stations"

#
# time sudo -u radio-pi sh bin/podcast-json-to-rdf.sh 
#

xmllint --version 2>/dev/null || { echo "Please install xmllint" ; exit 1 ; }
curl --version >/dev/null     || { echo "Please install curl" ; exit 1 ; }

cwd="$(pwd)"
dst="podcasts.rdf"

OSTYPE="$(uname)"
# Different sed version for different os types...
_sed() {
  # https://github.com/lukas2511/letsencrypt.sh/blob/master/letsencrypt.sh
  if [ "Linux" = "${OSTYPE}" ] ; then
    sed -r "${@}"
  else
    sed -E "${@}"
  fi
}

urlencode() {
  # http://stackoverflow.com/a/10797966
  echo -n "${1}" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" | cut -c 3-
}

ls */????/??/??/????\ *.json | cut -d / -f 1-4 | sort | uniq | while read dir
do
  # limit parallelism? http://stackoverflow.com/a/6513254
  {
    cd "${cwd}" && cd "${dir}"
    [ -r "${dst}" ] && { echo "${dir}/${dst} ... skipping" 1>&2 ; continue ; }
    {
      echo "${dir}" 1>&2
      echo "<?xml version='1.0' encoding='utf-8'?><rdf:RDF xmlns:dct='http://purl.org/dc/terms/' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
      for jso in *.json
      do
        broadcast="$(basename "${jso}" .json)"
        podcast="$(_sed 's/.+"name":"([^"]+)".+/\1/' "${jso}")"

        broadcast_url="$(urlencode "${broadcast}")"
        podcast_url="$(urlencode "${podcast}")"

        echo "<rdf:Description rdf:about='${broadcast_url}'><dct:isPartOf rdf:resource='../../../../../podcasts/${podcast_url}/'/></rdf:Description>"
      done
      echo "</rdf:RDF>"
    } > "${dst}"
    xmllint --noout "${dst}" || { echo "${dir}/${dst} broken" 1>&2 ; rm "${dst}" ; continue ; }
  } # & don't do parallel.
done

wait

cd "${cwd}"
ls */????/??/??/podcasts.rdf | wc -l
