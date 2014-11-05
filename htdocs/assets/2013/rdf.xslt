<?xml version="1.0" encoding="UTF-8"?>
<!--
  Turn broadcast xml into rdf

  built following http://www.w3.org/TR/grddl-tests/#sq2
  like http://www.w3.org/2001/sw/grddl-wg/td/sq1t.xsl
  
  http://wiki.dublincore.org/index.php/User_Guide/Publishing_Metadata#dcterms:date
  Literals & Languages: http://www.w3.org/TR/rdf11-concepts/#section-Graph-Literal
-->
<xsl:stylesheet
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3schools.com/RDF/rdf-schema.xml"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:dcmit="http://purl.org/dc/dcmitype/"
  xmlns:freq="http://purl.org/cld/freq/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:tl="http://purl.org/NET/c4dm/timeline.owl#"
  xmlns:iso639-1="http://lexvo.org/id/iso639-1/"
  xmlns:mime="http://purl.org/NET/mediatypes/"
  xmlns:rec="../../../../../assets/2013/radio-pi.rdf"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:ebu="http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="rec ebu"
  version="1.0">
  <xsl:output method="xml"/>
  <xsl:template match="rec:broadcast">
    <rdf:RDF xml:lang="{rec:meta[@name='DC.language']/@content}">
      <rdf:Description rdf:about="">
        <rdfs:label>Sendung</rdfs:label>
        <dct:identifier rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
          <xsl:value-of select="rec:meta[@name='DC.identifier']/@content"/>
        </dct:identifier>
        <dct:title>
          <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
        </dct:title>
        <dct:rightsHolder><rdf:Description><foaf:name>
          <xsl:value-of select="rec:meta[@name='DC.copyright']/@content"/>
        </foaf:name></rdf:Description></dct:rightsHolder>
        <dct:creator><rdf:Description><foaf:name>
          <xsl:value-of select="rec:meta[@name='DC.author']/@content"/>
        </foaf:name></rdf:Description></dct:creator>
        <dct:abstract>
          <xsl:value-of select="rec:meta[@name='DC.description']/@content"/>
        </dct:abstract>
        <dct:temporal>
          <tl:Interval>
            <tl:start rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
              <xsl:value-of select="rec:meta[@name='DC.format.timestart']/@content"/>
            </tl:start>
            <tl:end rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
              <xsl:value-of select="rec:meta[@name='DC.format.timeend']/@content"/>
            </tl:end>
            <tl:durationXSD rdf:datatype="http://www.w3.org/2001/XMLSchema#duration"><!--
              -->PT<xsl:value-of select="format-number(rec:meta[@name='DC.format.duration']/@content,0)"/>S<!--
            --></tl:durationXSD>
            <tl:durationInt rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">
              <xsl:value-of select="format-number(rec:meta[@name='DC.format.duration']/@content,0)"/>
            </tl:durationInt>
            <tl:timeline rdf:resource="http://purl.org/NET/c4dm/timeline.owl#universaltimeline"/>
          </tl:Interval>
        </dct:temporal>
        <dct:references rdf:resource="{rec:meta[@name='DC.image']/@content}"/>
        <dct:language rdf:resource="http://lexvo.org/id/iso639-1/{rec:meta[@name='DC.language']/@content}"/>
        <dct:publisher><rdf:Description><foaf:name>
          <xsl:value-of select="rec:meta[@name='DC.publisher']/@content"/>
        </foaf:name></rdf:Description></dct:publisher>
        <dct:source rdf:resource="{rec:meta[@name='DC.source']/@content}"/>
        <dct:alternative>
          <xsl:value-of select="rec:meta[@name='DC.title.episode']/@content"/>
        </dct:alternative>
        <dc:titleSeries>
          <xsl:value-of select="rec:meta[@name='DC.title.series']/@content"/>
        </dc:titleSeries>
        <dct:hasFormat rdf:resource="../../../../../enclosures/{rec:meta[@name='DC.identifier']/@content}.mp3"/>
        <dct:isPartOf rdf:resource="."/>
        <!-- dct:references rdf:resource="../../../../../enclosures/"/ -->
        <!-- dct:references>hu
          <xsl:value-of select="base-uri('.')"/>
        </dct:references -->
          <!-- http://stackoverflow.com/questions/582957/get-file-name-using-xsl -->
          <!-- xsl:value-of select="system-property('xsl:version')"/ -->
          <!-- xsl:value-of select="base-uri()"/ -->
        <!-- dct:isPartOf rdf:resource="../../../../../podcasts/radiowelt/"/ -->
        <dct:isReferencedBy rdf:resource="../../../../modified.ttl"/>
      </rdf:Description>
      <xsl:if test="string-length(rec:meta[@name='DC.image']/@content) > 0">
        <dcmit:StillImage rdf:about="{rec:meta[@name='DC.image']/@content}">
          <dct:format rdf:resource="http://purl.org/NET/mediatypes/image/jpeg"/>
          <dct:isReferencedBy rdf:resource=""/>
        </dcmit:StillImage>
      </xsl:if>
      <!-- dcmit:Sound rdf:about="../../../../../enclosures/{rec:meta[@name='DC.identifier']/@content}.mp3">
        <dct:format rdf:resource="http://purl.org/NET/mediatypes/audio/mp3"/>
        <dct:isFormatOf rdf:resource=""/>
      </dcmit:Sound -->
      <rdf:Description about=".">
        <rdfs:label>Tag</rdfs:label>
        <dct:hasPart rdf:resource=""/>
        <dct:isPartOf rdf:resource=".."/>
      </rdf:Description>
      <rdf:Description about="..">
        <rdfs:label>Monat</rdfs:label>
        <dct:hasPart rdf:resource="."/>
        <dct:isPartOf rdf:resource="../.."/>
      </rdf:Description>
      <rdf:Description about="../..">
        <rdfs:label>Jahr</rdfs:label>
        <dct:hasPart rdf:resource=".."/>
        <dct:isPartOf rdf:resource="../../.."/>
      </rdf:Description>
      <rdf:Description about="../../..">
        <rdfs:label>Sender</rdfs:label>
        <dct:hasPart rdf:resource="../.."/>
        <dct:isPartOf rdf:resource="../../../.."/>
      </rdf:Description>
      <rdf:Description about="../../../..">
        <dct:hasPart rdf:resource="../../.."/>
        <dct:isPartOf rdf:resource="../../../../.."/>
        <dct:relation rdf:resource="../../../../modified.ttl"/>
      </rdf:Description>
      <rdf:Description about="../../../../..">
        <dct:hasPart rdf:resource="../../../.."/>
        <!-- dct:hasPart rdf:resource="../../../../../podcasts/"/ -->
      </rdf:Description>
      <rdf:Description about="../../../../modified.ttl">
        <rdfs:label>aktualisierte Sendungen</rdfs:label>
        <dct:accrualPeriodicity>
          <rdf:Description about="http://purl.org/cld/freq/hourly">
            <rdfs:label>stündlich</rdfs:label>
            <dct:extent>
              <xsl:comment>http://wiki.dublincore.org/index.php/User_Guide/Publishing_Metadata#dcterms:extent</xsl:comment>
              <rdf:Description>
                <rdfs:label rdf:datatype="http://www.w3.org/2001/XMLSchema#duration">PT1H</rdfs:label>
              </rdf:Description>
            </dct:extent>
          </rdf:Description>
        </dct:accrualPeriodicity>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
</xsl:stylesheet>
