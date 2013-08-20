
Surprisingly, xslt is totally sufficient to scrape at least the schedule from http://br.de.

# Examples

Get all day-schedule links (as RDF)

    $ xsltproc --html br-days.xslt http://www.br.de/radio/bayern2/programmkalender/programmfahne102.html

Get all broadcasts per day (as RDF)

    $ xsltproc --html br-broadcasts.xslt http://www.br.de/radio/bayern2/programmkalender/programmfahne102.html

Get all broadcasts for all days (as RDF)

    $ ./b2.sh | rapper --input turtle --output rdfxml-abbrev - .
