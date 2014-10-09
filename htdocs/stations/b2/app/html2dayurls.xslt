<?xml version="1.0" encoding="UTF-8"?>
<!--
 Find all program schedule urls (one per day).

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
  xmlns:dcmit="http://purl.org/dc/dcmitype/"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0">
  
  <xsl:output method="xml"/>

  <xsl:variable name="date_prefix">~_date-</xsl:variable>
  <xsl:variable name="date_suffix">_-</xsl:variable>

  <xsl:template match="/">
    <rdf:RDF>
      <xsl:for-each select=".//a/@href[contains(., $date_prefix)]">
        <xsl:variable name="date_tail" select="substring-after(., $date_prefix)"/>
        <xsl:variable name="day" select="substring-before($date_tail, $date_suffix)"/>
        <dcmit:Text rdf:about="{.}">
          <dct:date rdf:datatype="http://www.w3.org/2001/XMLSchema#date"><xsl:value-of select="$day"/></dct:date>
        </dcmit:Text>
      </xsl:for-each>
    </rdf:RDF>
  </xsl:template>
</xsl:stylesheet>
