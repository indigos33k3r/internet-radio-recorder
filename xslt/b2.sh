#!/bin/sh
cd "$(dirname "$0")"

program_url="http://www.br.de/radio/bayern2/programmkalender/programmfahne102.html"
# program_url="http://www.br.de/radio/br-klassik/programmkalender/br-klassik120.html"
program_url="http://www.br.de/radio/b5-aktuell/programmkalender/b5aktuell116.html"

counter=0
for day_url in $(xsltproc --html br-days.xslt "$program_url" \
| rapper --input rdfxml --output turtle - . \
| egrep -hoe "^<http.*>" \
| egrep -hoe "http://.*html")
do
	counter=$((counter+1))
	if [ $((counter % 3)) -ne 2 ] ; then
		# as each 'day' schedule contains the previous and next day also, we just need
		# to look at every 3rd...
		continue
	fi
	echo "day $counter: $day_url" 1>&2
	# todo: scrape only 1 of 3
	xsltproc --stringparam closedown-hour 5 --html br-broadcasts.xslt "$day_url" \
	| rapper --input rdfxml --output turtle - .
done
