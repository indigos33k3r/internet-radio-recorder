<?xml version="1.0" encoding="UTF-8"?>
<!--
  Turn broadcast xml into html, used client-side, by the browser.

  Supposed to be either linked to from or located in station/<name>/app/broadcast2html.xslt,
  so each station could provide a custom skin.

 Copyright (c) 2013-2015 Marcus Rohrmoser, http://purl.mro.name/recorder

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
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:rec="../../../../../assets/2013/radio-pi.rdf"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="rec"
  version="1.0">

  <xsl:import href="../../../assets/broadcast2html.xslt"/>

  <!-- relative path... -->
  <xsl:variable name="station_about_rdf" select="document('../about.rdf')"/>

  <xsl:template name="broadcast_station_source">
    <xsl:variable name="dtstart" select="rec:meta[@name='DC.format.timestart']/@content"/>
    <xsl:variable name="year" select="substring($dtstart, 1, 4)"/>
    <xsl:variable name="month" select="substring($dtstart, 6, 2)"/>
    <xsl:variable name="day" select="substring($dtstart, 9, 2)"/>
    <xsl:variable name="hour" select="substring($dtstart, 12, 2)"/>
    <xsl:variable name="minute" select="substring($dtstart, 15, 2)"/>
    <form id="via" class="via" method="POST" action="http://www.radiofabrik.at/programm0/tagesprogramm.html" style="display:inline;margin:0;padding:0">
      <fieldset style="display:inline;margin:0;padding:0">
        <input type="hidden" name="si_day" value="{$day}" />
        <input type="hidden" name="si_month" value="{$month}" />
        <input type="hidden" name="si_year" value="{$year}" />
        <input type="hidden" name="f" value="listDay" />
        <button type="submit" name="send" value="wechseln" style="margin:0;padding:0; font-family:serif;font-size:100%;background:none; border:none; color:blue; text-decoration:underline; cursor:pointer;">Sendung</button>
      </fieldset>
    </form>,
  </xsl:template>
</xsl:stylesheet>
