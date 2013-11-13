<?xml version="1.0" encoding="UTF-8"?>
<!--
    extract broadcast links + dateTime + titles + text from dradio.de program day schedule

    $ xsltproc - -html broadcasts2rdf-dlf.xslt http://www.dradio.de/dlf/vorschau/

    http://www.w3.org/TR/xslt

 Copyright (c) 2013 Marcus Rohrmoser, https://github.com/mro/radio-pi

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
      <xsl:apply-templates select="/html/body/div[3]/div[2]/table[@class='vorschau-tabelle']/tr" />
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="tr">
    <xsl:variable name="dateTime"><xsl:value-of select="/html/head/meta[@name='date']/@content"/>T<xsl:value-of select="substring-before(normalize-space(td[@class='linke-spalte']),' ')"/>:00</xsl:variable>
    <rdf:Description rdf:about="{$dateTime}">
      <dcterms:language><xsl:value-of select="/html/head/meta[@http-equiv='content-language']/@content"/></dcterms:language>
      <dcterms:copyright><xsl:value-of select="/html/head/meta[@name='copyright']/@content"/></dcterms:copyright>
      <dcterms:last-modified><xsl:value-of select="/html/head/meta[@name='last-modified']/@content" /></dcterms:last-modified>
      <!-- start time only - end computed by broadcast-amend.lua assuming schedule starts 00:00 and ends 24:00 -->
      <dcterms:date><xsl:value-of select="$dateTime"/></dcterms:date>
      <xsl:for-each select="td[@class='rechte-spalte']/p/a[@class='link_arrow_right']/@href">
        <dcterms:relation rdf:resource="{.}" />
      </xsl:for-each>
      <dcterms:title>
        <xsl:choose>
          <xsl:when test="td[@class='rechte-spalte']/h2">
            <xsl:value-of select="normalize-space(td[@class='rechte-spalte']/h2)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="td[@class='rechte-spalte']/p/a[@class='link_arrow_right']"/>
          </xsl:otherwise>
        </xsl:choose>
      </dcterms:title>
      <dcterms:description>
        <xsl:for-each select="td[@class='rechte-spalte']/p">
          <xsl:for-each select="*|text()">
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

</xsl:stylesheet>
