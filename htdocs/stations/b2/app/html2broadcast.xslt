<?xml version="1.0" encoding="UTF-8"?>
<!--
  Copyright (c) 2013-2014 Marcus Rohrmoser, https://github.com/mro/radio-pi

  All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, are permitted
  provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice, this list of conditions
  and the following disclaimer.

  2. The software must not be used for military or intelligence or related purposes nor
  anything that's in conflict with human rights as declared in http://www.un.org/en/documents/udhr/ .

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-->
<!--
 Extract
 - all program schedule urls (one per day),
 - each broadcast's schedule + title

 Call like
 
 $ xsltproc - -stringparam station_about_url ../about.rdf - -html - -encoding utf-8 - -novalid html2broadcast.xslt http://www.br.de/radio/bayern2/programmkalender/sendung897954.html


 http://www.w3.org/TR/xslt
 http://www.w3.org/TR/xpath/
 http://wiki.dublincore.org/index.php/User_Guide/Creating_Metadata
-->
<xsl:stylesheet
  xmlns:rec="http://purl.mro.name/recorder/2014/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:tl="http://purl.org/NET/c4dm/timeline.owl#"
  xmlns:dcmit="http://purl.org/dc/dcmitype/"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:date="http://exslt.org/dates-and-times"
  xmlns:str="http://exslt.org/strings"
  extension-element-prefixes="date str"
  version="1.0">
<!--
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:mime="http://purl.org/NET/mediatypes/"
-->  
  <xsl:import href="html.xslt"/>
  <xsl:output method="xml" indent="yes"/>

  <!-- some handy constants -->
  <xsl:variable name="xsdTime">http://www.w3.org/2001/XMLSchema#time</xsl:variable>
  <xsl:variable name="xsdDate">http://www.w3.org/2001/XMLSchema#date</xsl:variable>
  <xsl:variable name="xsdDateTime">http://www.w3.org/2001/XMLSchema#dateTime</xsl:variable>
  <xsl:variable name="mime_html">http://purl.org/NET/mediatypes/text/html</xsl:variable>
  <xsl:variable name="mime_jpeg">http://purl.org/NET/mediatypes/image/jpeg</xsl:variable>

  <xsl:template match="/">
    <xsl:variable name="language" select="html/head/meta[@name = 'DCTERMS.title']/@lang"/>
    <xsl:if test="string-length($language) != 2"><xsl:message terminate="yes">FATAL: Couldn't figure out broadcast language</xsl:message></xsl:if>

    <!-- css 
      .bcast_head .avPlayer img , .bcast_head .picturebox img , .bcast_serial_picture .picturebox img
    -->
    <xsl:variable name="images" select=".//*[contains(@class, 'bcast_head')]//*[contains(@class, 'avPlayer')]//img
      | .//*[contains(@class, 'bcast_head')]//*[contains(@class, 'picturebox')]//img
      | .//*[contains(@class, 'bcast_serial_picture')]//*[contains(@class, 'picturebox')]//img"/>

    <rdf:RDF>    
      <dcmit:Text rdf:about="." xml:lang="{$language}">
        <rdfs:label xml:lang="deu">Sendungsseite</rdfs:label>
        <dct:format rdf:resource="{$mime_html}"/>

        <xsl:for-each select="html/head/meta[(@name = 'DCTERMS.title') and @content]">
          <xsl:element name="{concat('dct:', substring-after(@name, 'DCTERMS.'))}">
            <xsl:if test="@lang">
              <xsl:attribute name="xml:lang"><xsl:value-of select="@lang"/></xsl:attribute>
            </xsl:if>
            <xsl:value-of select="@content"/>
          </xsl:element>
        </xsl:for-each>
        <xsl:for-each select="html/head/meta[(@name = 'DCTERMS.creator') and @content]">
          <xsl:element name="{concat('dct:', substring-after(@name, 'DCTERMS.'))}">
            <xsl:if test="@lang">
              <xsl:attribute name="xml:lang"><xsl:value-of select="@lang"/></xsl:attribute>
            </xsl:if>
            <rdf:Description>
              <foaf:name>
                <xsl:value-of select="@content"/>
              </foaf:name>
            </rdf:Description>
          </xsl:element>
        </xsl:for-each>

        <xsl:for-each select=".//*[contains(@class, 'bcast_subtitle')]">
          <dct:alternate><xsl:value-of select="."/></dct:alternate>
        </xsl:for-each>

        <xsl:variable name="date_parts" select="str:tokenize(normalize-space(.//*[contains(@class, 'bcast_date')]), '., ')"/>
        <xsl:variable name="date_raw">
          <xsl:value-of select="$date_parts[4]"/>-<xsl:value-of select="$date_parts[3]"/>-<xsl:value-of select="$date_parts[2]"/>
        </xsl:variable>
        <xsl:variable name="date" select="date:date($date_raw)"/>
        <xsl:if test="string-length($date) != 10"><xsl:message terminate="yes">FATAL: Couldn't figure out broadcast date</xsl:message></xsl:if>

        <xsl:variable name="time_start"><!--
          --><xsl:value-of select="$date"/><!--
          -->T<!--
          --><xsl:value-of select="$date_parts[5]"/><!--
          -->:00<!--
        --></xsl:variable>
        <xsl:if test="string-length($time_start) != 19"><xsl:message terminate="yes">FATAL: Couldn't figure out broadcast start time</xsl:message></xsl:if>

        <xsl:variable name="time_end"><!--
          --><xsl:value-of select="$date"/><!--
          -->T<!--
          --><xsl:value-of select="$date_parts[7]"/><!--
          -->:00<!--
        --></xsl:variable>
        <xsl:if test="string-length($time_end) != 19"><xsl:message terminate="yes">FATAL: Couldn't figure out broadcast end time</xsl:message></xsl:if>

        <dct:temporal>
          <tl:Interval>
            <xsl:variable name="duration" select="date:difference($time_start, $time_end)"/>
            <tl:durationXSD rdf:datatype="http://www.w3.org/2001/XMLSchema#duration">
              <xsl:value-of select="$duration"/>
            </tl:durationXSD>
            <tl:durationInt rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">
              <xsl:value-of select="date:seconds($duration)"/>
            </tl:durationInt>
            <tl:start rdf:datatype="{$xsdDateTime}"><xsl:value-of select="$time_start"/></tl:start>
            <tl:end rdf:datatype="{$xsdDateTime}"><xsl:value-of select="$time_end"/></tl:end>
            <tl:timeline rdf:resource="http://purl.org/NET/c4dm/timeline.owl#universaltimeline"/>
          </tl:Interval>
        </dct:temporal>

        <dct:description>
          <xsl:value-of select="str:html2ascii(.//p[@class = 'copytext'])"/>
        </dct:description>
      
        <xsl:for-each select="$images[1]">
          <dct:references rdf:resource="{@src}"/>
        </xsl:for-each>
      </dcmit:Text>

      <xsl:for-each select="$images">
        <dcmit:StillImage rdf:about="{@src}">
          <dct:format rdf:resource="{$mime_jpeg}"/>
          <dct:isReferencedBy rdf:resource="."/>
          <xsl:if test="@title">
            <dct:title><xsl:value-of select="@title"/></dct:title>
          </xsl:if>
          <xsl:if test="@alt != @title">
            <dct:description><xsl:value-of select="@alt"/></dct:description>
          </xsl:if>
        </dcmit:StillImage>
      </xsl:for-each>
    </rdf:RDF>
  </xsl:template>

</xsl:stylesheet>
