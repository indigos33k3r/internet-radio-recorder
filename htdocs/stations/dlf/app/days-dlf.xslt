<?xml version="1.0" encoding="UTF-8"?>
<!--
    extract day links from http://www.dradio.de/dlf/vorschau/ program calendar

    $ xsltproc - -html days-dlf.xslt http://www.dradio.de/dlf/vorschau/
    
    or rather (we need to http POST):
    
    $ curl --form year=2012 --form month=12 --form day=6 http://www.dradio.de/dlf/vorschau/ \
      | xsltproc - -html days-dlf.xslt -

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
    exclude-result-prefixes="xsl"
    version="1.0">
  <xsl:output method="text" />
  
  <xsl:template match="/">
    <rdf:RDF xml:base="http://www.dradio.de/dlf/vorschau/">
      <xsl:apply-templates select="//form[@id='archiv']" />
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="form">
  	<xsl:for-each select="select[@name='year']/option">
  	  <xsl:variable name="year" select="@value" />
  	  <xsl:for-each select="../../select[@name='month']/option">
  	    <xsl:variable name="month" select="@value" />
  	    <xsl:for-each select="../../select[@name='day']/option">
<xsl:value-of select="$year"/>-<xsl:value-of select="format-number($month,'00')"/>-<xsl:value-of select="format-number(@value,'00')"/>
<xsl:text>
</xsl:text>
  	    </xsl:for-each>
  	  </xsl:for-each>
  	</xsl:for-each>
  </xsl:template>
  
</xsl:stylesheet>
