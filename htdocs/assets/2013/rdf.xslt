<?xml version="1.0" encoding="UTF-8"?>
<!--
  Turn broadcast xml into rdf

  build following http://www.w3.org/TR/grddl-tests/#sq2
  like http://www.w3.org/2001/sw/grddl-wg/td/sq1t.xsl
-->
<xsl:stylesheet xmlns:rec="../../../../../assets/2013/radio-pi.rdf" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml"/>
  <xsl:template match="rec:broadcast">
    <rdf:RDF xmlns:tl="http://purl.org/NET/c4dm/timeline.owl#" xmlns:xsd="http://www.w3.org/2001/XMLSchema#" xmlns:ebu="http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/">
      <rdf:Description rdf:about="">
        <dc:title rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
        </dc:title>
        <dc:author rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.author']/@content"/>
        </dc:author>
        <dc:copyright rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.copyright']/@content"/>
        </dc:copyright>
        <dc:creator rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.creator']/@content"/>
        </dc:creator>
        <dc:description rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.description']/@content"/>
        </dc:description>
        <dc:extent>
          <tl:Interval>
            <tl:at rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
              <xsl:value-of select="rec:meta[@name='DC.format.timestart']/@content"/>
            </tl:at>
            <tl:end rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
              <xsl:value-of select="rec:meta[@name='DC.format.timeend']/@content"/>
            </tl:end>
          </tl:Interval>
        </dc:extent>
        <dc:image rdf:resource="{rec:meta[@name='DC.image']/@content}"/>
        <dc:language rdf:datatype="http://purl.org/dc/terms/ISO639-2">
          <xsl:value-of select="rec:meta[@name='DC.language']/@content"/>
        </dc:language>
        <dc:publisher rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.publisher']/@content"/>
        </dc:publisher>
        <dc:source rdf:resource="{rec:meta[@name='DC.source']/@content}"/>
        <dc:titleEpisode rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.title.episode']/@content"/>
        </dc:titleEpisode>
        <dc:titleSeries rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.title.series']/@content"/>
        </dc:titleSeries>
        <dcterms:relation rdf:resource="../../../../../enclosures/{rec:meta[@name='DC.identifier']/@content}.mp3"/>
        <dcterms:isPartOf rdf:resource="../../.."/>
        <!-- dcterms:references rdf:resource="../../../../../enclosures/"/ -->
        <!-- dcterms:references>hu
          <xsl:value-of select="base-uri('.')"/>
        </dcterms:references -->
          <!-- http://stackoverflow.com/questions/582957/get-file-name-using-xsl -->
          <!-- xsl:value-of select="system-property('xsl:version')"/ -->
          <!-- xsl:value-of select="base-uri()"/ -->
        <!-- dcterms:isPartOf rdf:resource="../../../../../podcasts/radiowelt/"/ -->
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
</xsl:stylesheet>
