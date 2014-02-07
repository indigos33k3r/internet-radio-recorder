<?xml version="1.0" encoding="UTF-8"?>
<!--
    extract broadcast links + dateTime + titles + text from dradio.de program day schedule

    $ xsltproc -html broadcasts2rdf-dlf.xslt http://www.deutschlandfunk.de/programmvorschau.281.de.html?drbm:date=19.11.2013

    http://www.w3.org/TR/xslt

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
<xsl:stylesheet
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:date="http://exslt.org/dates-and-times"
    exclude-result-prefixes="xsl"
    version="1.0">
  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/">
    <rdf:RDF>
      <xsl:apply-templates select="//*[@id='pageContentMain']//tbody//tr[@id]">
        <xsl:with-param name="date">
          <xsl:call-template name="DayMonthNameYear2ISO">
            <xsl:with-param name="src" select="substring-after(//h3[strong]/text(),',')"/>
          </xsl:call-template>
        </xsl:with-param>
      </xsl:apply-templates>
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="tr">
    <xsl:param name="date"/>
    <xsl:variable name="dateTime"><xsl:value-of select="$date"/>T<xsl:value-of select="normalize-space(translate(td[@class='time'], 'Uhr', '   '))"/>:00</xsl:variable>
    <rdf:Description rdf:about="{$dateTime}">
      <dcterms:language>de</dcterms:language>
      <dcterms:copyright>DLF</dcterms:copyright>
      <!-- dcterms:last-modified> </dcterms:last-modified -->
      <!-- start time only - end computed by broadcast-amend.lua assuming schedule starts 00:00 and ends 24:00 -->
      <dcterms:date><xsl:value-of select="$dateTime"/></dcterms:date>
      <xsl:for-each select="td[@class='description']/p/a[@class='link_arrow_right']/@href">
        <dcterms:relation rdf:resource="{.}" />
      </xsl:for-each>
      <xsl:for-each select="td[@class='description']/h4">
        <dcterms:title>
          <xsl:for-each select="*[not(name() = 'a' and @class = 'psradio')]|text()">
            <xsl:value-of select="normalize-space(.)"/>
          </xsl:for-each>
        </dcterms:title>
      </xsl:for-each>
      <dcterms:description>
        <xsl:for-each select="td[@class='description']/p">
          <xsl:for-each select="*[not(name() = 'a' and @class = 'psradio')]|text()">
            <xsl:choose>
              <xsl:when test="name() = 'br'"><xsl:text>&#10;<!-- linefeed --></xsl:text></xsl:when>
              <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
          <xsl:text>&#10;&#10;<!-- double linefeed --></xsl:text>
        </xsl:for-each>
      </dcterms:description>
    </rdf:Description>
  </xsl:template>

  <xsl:template name="DayMonthNameYear2ISO">
    <!-- turn e.g. '26. November 2013,' into 2013-11-26 -->
    <xsl:param name="src"/>
    <xsl:variable name="tmp" select="normalize-space(translate($src,'&#9;&#xa0;.,', '    '))"/>
    <xsl:variable name="day" select="format-number(substring-before($tmp, ' '),'00')"/>
    <xsl:variable name="month_year" select="substring-after($tmp, ' ')"/>
    <xsl:variable name="month_name" select="substring-before($month_year, ' ')"/>
    <xsl:variable name="year" select="substring-after($month_year, ' ')"/>
    <xsl:value-of select="$year"/>-<!--
    --><xsl:choose>
      <xsl:when test="$month_name = 'Dezember'">12</xsl:when>
      <xsl:when test="$month_name = 'November'">11</xsl:when>
      <xsl:when test="$month_name = 'Oktober'">10</xsl:when>
      <xsl:when test="$month_name = 'September'">09</xsl:when>
      <xsl:when test="$month_name = 'August'">08</xsl:when>
      <xsl:when test="$month_name = 'Juli'">07</xsl:when>
      <xsl:when test="$month_name = 'Juni'">06</xsl:when>
      <xsl:when test="$month_name = 'Mai'">05</xsl:when>
      <xsl:when test="$month_name = 'April'">04</xsl:when>
      <xsl:when test="$month_name = 'März'">03</xsl:when>
      <xsl:when test="$month_name = 'Februar'">02</xsl:when>
      <xsl:when test="$month_name = 'Januar'">01</xsl:when>
      <xsl:otherwise>Unknown month in: '<xsl:value-of select="$tmp"/>'</xsl:otherwise>
    </xsl:choose>-<!--
    --><xsl:value-of select="$day"/>
  </xsl:template>

</xsl:stylesheet>
