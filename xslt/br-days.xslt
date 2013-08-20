<?xml version="1.0" encoding="UTF-8"?>
<!--
    extract day links from BR program calendar

    $ xsltproc - -html br-days.xslt http://www.br.de/radio/bayern2/programmkalender/programmfahne102.html

    http://www.w3.org/TR/xslt
-->
<xsl:stylesheet
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    exclude-result-prefixes="xsl"
    version="1.0">
  <xsl:output method="xml" indent="yes"/>
  
  <xsl:template match="/">
    <rdf:RDF xml:base="http://www.br.de">
      <xsl:apply-templates select=".//div[@class='calendar']/div/div[@class='box_inlay']/table[@summary]" mode="month" />
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="table[@summary]" mode="month">
    <xsl:apply-templates select="tbody/tr/td/a" mode="days">
      <xsl:with-param name="year-month">
        <xsl:call-template name="YearAndMonth2ISO">
          <xsl:with-param name="src" select="substring-after(normalize-space(@summary), ' ')"/>
        </xsl:call-template> 
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="a" mode="days">
    <xsl:param name="year-month" />
    <rdf:Description rdf:about="{@href}">
      <dc:date rdf:datatype="http://www.w3.org/2001/XMLSchema#date"><xsl:value-of select="$year-month"/>-<xsl:value-of select="format-number(substring-before(.,'.'),'00')"/></dc:date>
    </rdf:Description>
  </xsl:template>
  
  <xsl:template name="YearAndMonth2ISO">
    <!-- turn e.g. September 2013 into 2013-09 -->
    <xsl:param name="src"/>
    <xsl:variable name="tmp" select="normalize-space($src)"/>
    <xsl:value-of select="substring-after($tmp,' ')"/>-<!--
    --><xsl:variable name="month_name" select="substring-before($tmp,' ')"/>
    <xsl:choose>
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
      <xsl:otherwise>Unknown month in: '<xsl:value-of select="text()"/>' (<xsl:value-of select="$src"/>) (<xsl:value-of select="$tmp"/>)</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>
