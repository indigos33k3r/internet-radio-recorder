<?xml version="1.0" encoding="UTF-8"?>
<!--
 Copyright (c) 2013-2014 Marcus Rohrmoser, https://github.com/mro/radio-pi

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
 associated documentation files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge, publish, distribute,
 sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
 NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
 OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 MIT License http://opensource.org/licenses/MIT
-->
<!--
 Extract
 - all program schedule urls (one per day),
 - each broadcast's schedule + title

 Call like
 
 $ xsltproc - -stringparam station_about_url ../about.rdf - -html - -encoding utf-8 - -novalid html2schedule.xslt http://www.br.de/radio/bayern2/programmkalender/programmfahne102.html


 http://www.w3.org/TR/xslt
 http://www.w3.org/TR/xpath/
 http://wiki.dublincore.org/index.php/User_Guide/Creating_Metadata
-->
<xsl:stylesheet
  xmlns:rec="http://purl.mro.name/recorder/2014/"
  xmlns:tl="http://purl.org/NET/c4dm/timeline.owl#"
  xmlns:dcmit="http://purl.org/dc/dcmitype/"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:date="http://exslt.org/dates-and-times"
  xmlns:func="http://exslt.org/functions"
  extension-element-prefixes="date func"
  version="1.0">
<!--
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:mime="http://purl.org/NET/mediatypes/"
-->  
  <xsl:output method="xml"/>

  <!-- some handy constants -->
  <xsl:variable name="xsdTime">http://www.w3.org/2001/XMLSchema#time</xsl:variable>
  <xsl:variable name="xsdDate">http://www.w3.org/2001/XMLSchema#date</xsl:variable>
  <xsl:variable name="xsdDateTime">http://www.w3.org/2001/XMLSchema#dateTime</xsl:variable>
  <xsl:variable name="mime_html">http://purl.org/NET/mediatypes/text/html</xsl:variable>

  <xsl:variable name="date_prefix">~_date-</xsl:variable>
  <xsl:variable name="date_suffix">_-</xsl:variable>

  <!-- extract curfew and language from station about.rdf -->
  <xsl:variable name="station_about" select="document($station_about_url)"/>
  <!-- xsl:variable name="station_url" select="$station_about/rdf:RDF/rdf:Description/@rdf:about"/ -->
  <xsl:variable name="curfew" select="$station_about/rdf:RDF/dcmit:Text/rec:curfew[@rdf:datatype = $xsdTime]"/>
  <xsl:variable name="language_uri" select="$station_about/rdf:RDF/dcmit:Text/dct:language/@rdf:resource"/>
  <xsl:variable name="language" select="substring-after($language_uri, '/iso639-3/')"/>

  <xsl:template match="/">
    <!-- some syntactic checks -->
    <xsl:if test="string-length($curfew) != 8">
      <xsl:message terminate="yes">Curfew must be a http://www.w3.org/2001/XMLSchema#time but was '<xsl:value-of select="$curfew"/>' </xsl:message>
    </xsl:if>
    <xsl:variable name="curfew_numeric" select="date:second-in-minute($curfew) + 100 * (date:minute-in-hour($curfew) + 100 * date:hour-in-day($curfew))"/>
    <xsl:if test="string-length($language) != 3">
      <xsl:message terminate="yes">language_uri must be a http://www.lexvo.org/id/iso639-3/ but was '<xsl:value-of select="$language"/>' </xsl:message>
    </xsl:if>

    <rdf:RDF>

      <!-- schedule urls -->

      <xsl:for-each select=".//a/@href[contains(., $date_prefix)]">
        <xsl:variable name="date_tail" select="substring-after(., $date_prefix)"/>
        <xsl:variable name="day" select="substring-before($date_tail, $date_suffix)"/>
        <rdf:Description rdf:about="{.}">
          <rdfs:label xml:lang="deu">Sendungsterminliste</rdfs:label>
          <dct:date rdf:datatype="http://www.w3.org/2001/XMLSchema#date"><xsl:value-of select="$day"/></dct:date>
          <dct:language rdf:resource="{$language_uri}"/>
          <dct:format rdf:resource="{$mime_html}"/>
        </rdf:Description>
      </xsl:for-each>

      <!-- broadcast schedule entries -->

      <xsl:variable name="yesterday_url" select="//li[@class='multidays_prev']/a/@href"/>
      <xsl:variable name="yesterday_tail" select="substring-after($yesterday_url, $date_prefix)"/>      
      <xsl:variable name="yesterday" select="substring-before($yesterday_tail, $date_suffix)"/>

      <xsl:if test="string-length($yesterday)">
        <xsl:variable name="today" select="date:add($yesterday, 'P1D')"/>
        <xsl:variable name="tomorrow" select="date:add($yesterday, 'P2D')"/>
        <xsl:if test="string-length($yesterday) + string-length($today) + string-length($tomorrow) > 0">
          <xsl:for-each select=".//a[
            contains(@class, 'link_broadcast')
            and @href
            and (
              ../../../@class = 'day_1'
              or ../../../@class = 'day_2'
              or ../../../@class = 'day_3'
            ) 
          ]">
            <xsl:variable name="dateRaw">
              <xsl:choose>
                <xsl:when test="../../../@class = 'day_1'"><xsl:value-of select="$yesterday"/></xsl:when>
                <xsl:when test="../../../@class = 'day_2'"><xsl:value-of select="$today"/></xsl:when>
                <xsl:when test="../../../@class = 'day_3'"><xsl:value-of select="$tomorrow"/></xsl:when>
                <xsl:otherwise><xsl:comment>how odd.</xsl:comment></xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <!-- some syntactic checks -->
            <xsl:if test="string-length($dateRaw) != 10">
              <xsl:message terminate="yes">date must be a http://www.w3.org/2001/XMLSchema#date but was '<xsl:value-of select="$dateRaw"/>' </xsl:message>
            </xsl:if>

            <xsl:variable name="time"><xsl:value-of select="strong"/>:00</xsl:variable>
            <!-- some syntactic checks -->
            <xsl:if test="string-length($time) != 8">
              <xsl:message terminate="yes">Time must be a http://www.w3.org/2001/XMLSchema#time but was '<xsl:value-of select="$time"/>' </xsl:message>
            </xsl:if>

            <xsl:variable name="date">
              <xsl:variable name="time_numeric" select="date:second-in-minute($time) + 100 * (date:minute-in-hour($time) + 100 * date:hour-in-day($time))"/>
              <xsl:choose>
                <!-- add one day if between midnight and curfew -->
                <xsl:when test="number($time_numeric) &lt; number($curfew_numeric)"><xsl:value-of select="date:add($dateRaw, 'P1D')"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="$dateRaw"/></xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:variable name="dateTime"><xsl:value-of select="$date"/>T<xsl:value-of select="$time"/></xsl:variable>
            <!-- some syntactic checks -->
            <xsl:if test="string-length($dateTime) != 19">
              <xsl:message terminate="yes">dateTime must be a http://www.w3.org/2001/XMLSchema#dateTime but was '<xsl:value-of select="$dateTime"/>' </xsl:message>
            </xsl:if>
            <!--
            <xsl:variable name="year" select="date:year($dateTime)"/>
            <xsl:variable name="month"><xsl:number value="date:month-in-year($dateTime)" format="01"/></xsl:variable>
            <xsl:variable name="day"><xsl:number value="date:day-in-month($dateTime)" format="01"/></xsl:variable>
            <xsl:variable name="hour"><xsl:number value="date:hour-in-day($dateTime)" format="01"/></xsl:variable>
            <xsl:variable name="minute"><xsl:number value="date:minute-in-hour($dateTime)" format="01"/></xsl:variable>
            <xsl:variable name="second"><xsl:number value="date:second-in-minute($dateTime)" format="01"/></xsl:variable>
            <xsl:variable name="identifier"><xsl:value-of select="$year"/>/<xsl:value-of select="$month"/>/<xsl:value-of select="$day"/>/<xsl:value-of select="$hour"/><xsl:value-of select="$minute"/><xsl:value-of select="$second"/></xsl:variable>
            -->
            <!--
            <xsl:variable name="url"><xsl:value-of select="$station_url"/><xsl:value-of select="$identifier"/></xsl:variable>
            -->
            <xsl:variable name="title"><xsl:value-of select="normalize-space(strong/following-sibling::text())"/></xsl:variable>

            <dcmit:Event rdf:about="{@href}">
              <rdfs:label xml:lang="deu">Sendungsseite</rdfs:label>
              <dct:format rdf:resource="{$mime_html}"/>
              <dct:title xml:lang="{$language}"><xsl:value-of select="$title"/></dct:title>
              <!-- dc:identifier><xsl:value-of select="$identifier"/></dc:identifier -->
              <dct:date rdf:datatype="{$xsdDateTime}"><xsl:value-of select="$dateTime"/></dct:date>
              <!-- use temporal once we have the proper timezone.
                <dct:temporal>
                <tl:Interval>
                  <tl:start rdf:datatype="{$xsdDateTime}"><xsl:value-of select="$dateTime"/></tl:start>
                  <tl:timeline rdf:resource="http://purl.org/NET/c4dm/timeline.owl#universaltimeline"/>
                </tl:Interval>
              </dct:temporal -->
            </dcmit:Event>
          </xsl:for-each>
        </xsl:if>
      </xsl:if>
    </rdf:RDF>
  </xsl:template>
</xsl:stylesheet>
