<?xml version="1.0" encoding="UTF-8"?>
<!--
  Turn broadcast xml into html, used client-side, by the browser.

  Supposed to be either linked to from or located in station/<name>/app/broadcast2html.xslt,
  so each station could provide a custom skin.

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
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:rec="../../../../../assets/2013/radio-pi.rdf"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="rec"
  version="1.0">

  <xsl:template name="linefeed2br">
    <xsl:param name="string" select="''"/>
    <xsl:param name="pattern" select="'&#10;'"/>
    <xsl:choose>
      <xsl:when test="contains($string, $pattern)">
        <xsl:value-of select="substring-before($string, $pattern)"/><br class="br"/><xsl:comment>Why do we see 2 br on Safari and output/@method=html here? http://purl.mro.name/safari-xslt-br-bug</xsl:comment>
        <xsl:call-template name="linefeed2br">
          <xsl:with-param name="string" select="substring-after($string, $pattern)"/>
          <xsl:with-param name="pattern" select="$pattern"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$string"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:output
    method="html"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
    doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"/>
  <xsl:template match="rec:broadcast">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="{rec:meta[@name='DC.language']/@content}">
      <head>
        <meta content="text/html; charset=utf-8" http-equiv="content-type"/>
        <!-- https://developer.apple.com/library/IOS/documentation/AppleApplications/Reference/SafariWebContent/UsingtheViewport/UsingtheViewport.html#//apple_ref/doc/uid/TP40006509-SW26 -->
        <!-- http://maddesigns.de/meta-viewport-1817.html -->
        <!-- meta name="viewport" content="width=device-width"/ -->
        <!-- http://www.quirksmode.org/blog/archives/2013/10/initialscale1_m.html -->
        <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
        <!-- meta name="viewport" content="width=400"/ -->
        <link href="../../../../../assets/favicon-32x32.png" rel="shortcut icon" type="image/png" />
        <link href="../../../../../assets/favicon-512x512.png" rel="apple-touch-icon" type="image/png" />
        <link href="../../../app/style.css" rel="stylesheet" type="text/css"/>
        <title>
          <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
        </title>
        <link href="{rec:meta[@name='DC.source']/@content}" rel="via"/>
        <link href="../../../../../app/prev.lua" rel="prev"/>
        <link href="../../../../../app/next.lua" rel="next"/>
        <link href="index.html" rel="parent"/>
        <!-- link href='../../../../../enclosures/app/schedule.lua?uri=referer' rel='edit-media'/ -->
        <xsl:for-each select="rec:meta">
          <meta content="{@content}" name="{@name}"/>
        </xsl:for-each>
      </head>
      <body id="broadcast">
        <noscript><p>JavaScript ist aus, es geht zwar (fast) alles auch ohne, aber mit ist's <b>schöner</b>. (Datumsformatierung, Aufnahmen wieder stornieren, Tagesübersicht, Link zum Stream)</p></noscript>
        <ul id="whatsonnow"><li>Dummy</li></ul>
        <p id="navigation" title="Navigation">
            <a id="prev_week" href="../../../../../app/now.lua?t=P-7D" title="Woche vorher">&lt;&lt;&lt;</a>&#x00A0;
            <a id="yesterday" href="../../../../../app/now.lua?t=P-1D" title="Tag vorher">&lt;&lt;</a>&#x00A0;
            <a class="large" href="../../../../../app/prev.lua" rel="prev" title="Sendung vorher">&lt;</a>&#x00A0;
            <a class="large" href="../../../now">aktuell</a>&#x00A0;
            <a class="large" href="../../../../../app/next.lua" rel="next" title="Sendung nachher">&gt;</a>&#x00A0;
            <a id="tomorrow" href="../../../../../app/now.lua?t=P1D" title="Tag nachher">&gt;&gt;</a>&#x00A0;
            <a id="next_week" href="../../../../../app/now.lua?t=P7D" title="Woche nachher">&gt;&gt;&gt;</a>
        </p>
        <h2 id="series">
          <xsl:value-of select="rec:meta[@name='DC.title.series']/@content"/>
        </h2>
        <h1 id="title">
          <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
        </h1>
        <h2 id="summary">
          <xsl:value-of select="rec:meta[@name='DC.title.episode']/@content"/>
        </h2>
        <p>
          <xsl:variable name="dtstart" select="rec:meta[@name='DC.format.timestart']/@content"/>
          <xsl:variable name="year" select="substring($dtstart, 1, 4)"/>
          <xsl:variable name="month" select="substring($dtstart, 6, 2)"/>
          <xsl:variable name="day" select="substring($dtstart, 9, 2)"/>
          <xsl:variable name="hour" select="substring($dtstart, 12, 2)"/>
          <xsl:variable name="minute" select="substring($dtstart, 15, 2)"/>
          <a id="via" class="via" href="http://www.deutschlandfunk.de/programmvorschau.281.de.html?drbm:date={$day}.{$month}.{$year}#anc{$hour}{$minute}">www.dradio.de</a>,
          <a id="stream" style="display:none">Live Stream</a>
        </p>
        <p id="date">
          <span id="dtstart" title="{rec:meta[@name='DC.format.timestart']/@content}"><xsl:value-of select="rec:meta[@name='DC.format.timestart']/@content"/></span>
          bis
          <span id="dtend" title="{rec:meta[@name='DC.format.timeend']/@content}"><xsl:value-of select="rec:meta[@name='DC.format.timeend']/@content"/></span>
        </p>
        <p class="image">
          <img alt="Bild zur Sendung" id="image" src="{rec:meta[@name='DC.image']/@content}"/>
        </p>
        <div id="content">
          <p>
          <xsl:call-template name="linefeed2br">
            <xsl:with-param name="string" select="rec:meta[@name='DC.description']/@content"/>
          </xsl:call-template>
          </p>
        </div>
        <h3>Podcast</h3>
        <p id="podcasts" class="podcasts">keiner</p>
        <form id="ad_hoc" method="post" action="../../../../../enclosures/app/ad_hoc.cgi">
          <fieldset>
          <input id="ad_hoc_action" type="hidden" name="add" value="referer"/>
          <input id="ad_hoc_submit" type="submit" value="Aufnehmen"/>
          </fieldset>
        </form>
        <p id="enclosure">
          <!-- audio controls="controls" style="display:none">Doesn't play well with auth...<source type="audio/mpeg" /></audio -->
          <a id="enclosure_link">mp3</a></p>
        <hr/>
        <ul id="allday" class="nobullet" style="display:none"><li>Dummy</li></ul>
        <p><a href=".">Verzeichnis Index</a></p>
        <hr/>
        <p id="footer">
          <!--
          <a style="display:none" href="http://validator.w3.org/check?uri=referer">
          <img alt="Valid XHTML 1.0 Strict" height="31" src="http://www.w3.org/Icons/valid-xhtml10-blue.png" width="88"/>
          </a>
          <a style="display:none" href="http://jigsaw.w3.org/css-validator/check/referer?profile=css3&amp;usermedium=screen&amp;warning=2&amp;vextwarning=false&amp;lang=de">
          <img alt="CSS ist valide!" src="http://jigsaw.w3.org/css-validator/images/vcss-blue" style="border:0;width:88px;height:31px"/>
          </a>
          -->
          Powered by <a href="https://github.com/mro/radio-pi">github.com/mro/radio-pi</a><br class="br"/>
          RDF: <tt>$ <a href="http://librdf.org/raptor/rapper.html">rapper</a> -i grddl -o rdfxml-abbrev '<span id="my-url">&lt;url from address bar&gt;</span>'</tt>
        </p>
        <script type="text/javascript" src="../../../../../assets/jquery-2.0.0.min.js"/>
        <script type="text/javascript" src="../../../../../assets/moment.min.js"/><!-- http://momentjs.com/ -->
        <script type="text/javascript" src="../../../../../assets/lang/de.js"/><!-- https://github.com/timrwood/moment/blob/develop/min/lang/de.js -->
        <script type="text/javascript" src="../../../../../assets/broadcast2html.js" />
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
