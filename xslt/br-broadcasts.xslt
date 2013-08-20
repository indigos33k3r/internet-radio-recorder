<?xml version="1.0" encoding="UTF-8"?>
<!--
    extract broadcast links + titles + dateTime from BR program day schedule

    $ xsltproc - -html - -stringparam closedown-hour 06 br-broadcasts.xslt http://www.br.de/radio/bayern2/programmkalender/programmfahne102.html

    http://www.w3.org/TR/xslt
-->
<xsl:stylesheet
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:date="http://exslt.org/dates-and-times"
    extension-element-prefixes="date"
    exclude-result-prefixes="xsl"
    version="1.0">
  <xsl:output method="xml" indent="yes"/>

  <!--
    The daily schedule has the odd habit to list broadcasts between midnight and 
    closedown with the previous day. So we have to add PD1 (one day) to the date
    for those broadcasts.
  -->
  <xsl:param name="closedown-hour">05</xsl:param>

  <xsl:template match="/">
    <rdf:RDF xml:base="http://www.br.de">
      <xsl:apply-templates select=".//div[@class='detail_inlay']/div/div[@class='day_1' or @class='day_2' or @class='day_3']" mode="day" />
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="div" mode="day">
    <xsl:variable name="tmp" select="normalize-space(translate(substring-after(h4,','),'.',' '))"/>
    <xsl:apply-templates select="dl/dt/a[@href and strong]" mode="broadcast">
      <xsl:with-param name="month-number" select="substring-after($tmp,' ')" />
      <xsl:with-param name="day-number" select="substring-before($tmp,' ')" />
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="a" mode="broadcast">
    <xsl:param name="month-number" />
    <xsl:param name="day-number" />
    <rdf:Description rdf:about="{@href}">
      <dc:title><xsl:value-of select="substring-after(normalize-space(.),' ')"/></dc:title>
      <xsl:comment> CAUTION! days will overflow end of month for broadcasts on last day of month between 00:00 and <xsl:value-of select="$closedown-hour"/>:00 </xsl:comment>
      <!-- maybe use http://www.exslt.org/date/functions/add/index.html ? -->
      <xsl:variable name="hour" select="substring-before(strong,':')"/>
      <xsl:variable name="real-day">
      	<xsl:choose>
      	  <xsl:when test="$hour &lt; $closedown-hour"><xsl:value-of select="$day-number + 1"/></xsl:when>
      	  <xsl:otherwise><xsl:value-of select="$day-number"/></xsl:otherwise>
      	</xsl:choose>
      </xsl:variable>
      <xsl:variable name="temp-date">
		<xsl:call-template name="YearForMonthNumber">
          <xsl:with-param name="month-number" select="$month-number" />             
        </xsl:call-template><!--
        -->-<xsl:value-of select="$month-number"/><!--
        -->-<xsl:value-of select="format-number($real-day,'00')"/><!--
        -->T<xsl:value-of select="strong"/>:00<!--
      --></xsl:variable>
      <dc:date rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
        <xsl:value-of select="$temp-date"/>
      </dc:date>
    </rdf:Description>
  </xsl:template>

  <xsl:template name="YearForMonthNumber">
    <!-- extract year from calendar table@summary with matching month name -->
    <xsl:param name="month-number" />
    <xsl:variable name="month-name">
      <xsl:choose>
        <xsl:when test="$month-number = '01'">Januar</xsl:when>
        <xsl:when test="$month-number = '02'">Februar</xsl:when>
        <xsl:when test="$month-number = '03'">März</xsl:when>
        <xsl:when test="$month-number = '04'">April</xsl:when>
        <xsl:when test="$month-number = '05'">Mai</xsl:when>
        <xsl:when test="$month-number = '06'">Juni</xsl:when>
        <xsl:when test="$month-number = '07'">Juli</xsl:when>
        <xsl:when test="$month-number = '08'">August</xsl:when>
        <xsl:when test="$month-number = '09'">September</xsl:when>
        <xsl:when test="$month-number = '10'">Oktober</xsl:when>
        <xsl:when test="$month-number = '11'">November</xsl:when>
        <xsl:when test="$month-number = '12'">Dezember</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="YearHint" select="normalize-space(//div[@class='calendar']/div/div[@class='box_inlay']/table[contains(@summary,$month-name)]/@summary)" />
    <xsl:value-of select="substring-after(substring-after($YearHint,' '),' ')"/>
  </xsl:template>
</xsl:stylesheet>
