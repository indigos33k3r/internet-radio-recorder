<?xml version="1.0" encoding="UTF-8"?>
<!--
  Turn broadcast xml into html, used client-side, by the browser.

  Supposed to be either
  - linked to (ln -s) from stations/<name>/app/broadcast2html.xslt
  - xsl:import-ed from a custom stations/<name>/app/broadcast2html.xslt,
  - automatically rewritten to from stations/<name>/app/broadcast2html.xslt
  so each station can provide a custom skin but uses the generic one as a fallback.

  See stations/dlf/app/broadcast2html.xslt for an example for xsl:import.

 Copyright (c) 2013-2016 Marcus Rohrmoser, http://purl.mro.name/recorder

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

 CSS classes use https://en.wikipedia.org/wiki/HCalendar#Example

 http://www.w3.org/TR/xslt/
-->
<xsl:stylesheet
  xmlns:rec="../../../../../assets/2013/radio-pi.rdf"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dctype="http://purl.org/dc/dcmitype/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:svg="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  exclude-result-prefixes="rec foaf dctype rdf svg xlink"
  xmlns:date="http://exslt.org/date"
  extension-element-prefixes="date"
  version="1.0">

  <!-- replace linefeeds with <br> tags -->
  <xsl:template name="linefeed2br">
    <xsl:param name="string" select="''"/>
    <xsl:param name="pattern" select="'&#10;'"/>
    <xsl:choose>
      <xsl:when test="contains($string, $pattern)">
        <xsl:value-of select="substring-before($string, $pattern)"/><br class="br"/><xsl:comment> Why do we see 2 br on Safari and output/@method=html here? http://purl.mro.name/safari-xslt-br-bug </xsl:comment>
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

  <!-- load external additional xml documents -->
  <xsl:variable name="station_about_rdf" select="document('../about.rdf')"/>
  <xsl:variable name="now_fellows_xml" select="document('../../../../app/now.lua')"/>

  <xsl:template name="broadcast_station_source">
    <a class="via" href="{rec:meta[@name='DC.source']/@content}" rel="via">Sendung</a>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template name="station_rdf_logo">
    <xsl:variable name="station_rdf0" select="$station_about_rdf/rdf:RDF/foaf:Document[ '' = @rdf:about ]"/>
    <xsl:variable name="station_rdf1" select="$station_about_rdf/rdf:RDF/*[ $station_rdf0/foaf:primaryTopic/@rdf:resource = @rdf:about ]"/>
    <xsl:variable name="station_rdf" select="$station_about_rdf/rdf:RDF/rdf:Description">
      <!-- currently there's only 1 rdf:Description, all others are of different dctype -->
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$station_rdf">
        <a title="{$station_rdf/foaf:name} Programm" href="{$station_rdf/../dctype:Text/@rdf:about}">
          <img alt="Senderlogo {$station_rdf/foaf:name}" src="{$station_rdf/foaf:logo/@rdf:resource}" style="height:30px" class="border"/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <span title="No station RDF found at ../../../about.rdf" style="color:red;font-weight:bolder">!</span>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template name="station_rdf_stream">
    <xsl:variable name="stream_rdf" select="$station_about_rdf/rdf:RDF/dctype:Sound[@rdf:about]"/>
    <xsl:choose>
      <xsl:when test="$stream_rdf">
        <a style="color:green" class="location" title="{$stream_rdf/@rdf:about}" href="{$stream_rdf/@rdf:about}">Live Stream</a>
      </xsl:when>
      <xsl:otherwise>
        <!-- keep the fallback to jquery + GET station.cfg for now: -->
        <a id="stream" style="display:none">Live Stream</a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="station_logo">
    <xsl:param name="id" select="."/>
    <xsl:choose>
      <!-- could be pulled from the about.rdf -->
    <!--
      <xsl:when test="$id = 'b1'">https://upload.wikimedia.org/wikipedia/de/e/e3/Bayern_plus.svg</xsl:when>
      <xsl:when test="$id = 'b2'">https://upload.wikimedia.org/wikipedia/de/2/27/Bayern_2_%282007%29.svg</xsl:when>
      <xsl:when test="$id = 'b3'">https://upload.wikimedia.org/wikipedia/commons/d/de/Bayern3_logo_2015.svg</xsl:when>
      <xsl:when test="$id = 'b4'">https://upload.wikimedia.org/wikipedia/de/c/ca/BR-Klassik.svg</xsl:when>
      <xsl:when test="$id = 'b5'">https://upload.wikimedia.org/wikipedia/de/9/9f/B5_aktuell_%282007%29.svg</xsl:when>
      <xsl:when test="$id = 'b+'">https://upload.wikimedia.org/wikipedia/de/e/e3/Bayern_plus.svg</xsl:when>
      <xsl:when test="$id = 'brheimat'">https://upload.wikimedia.org/wikipedia/commons/d/d0/BR_Heimat_Logo.svg</xsl:when>
      <xsl:when test="$id = 'puls'">https://upload.wikimedia.org/wikipedia/commons/e/e7/BR_puls_Logo.svg</xsl:when>
      <xsl:when test="$id = 'm945'">http://www.m945.de/images/logo_footer.png</xsl:when>
      <xsl:when test="$id = 'dlf'">https://upload.wikimedia.org/wikipedia/commons/f/fd/Deutschlandfunk.svg</xsl:when>
      <xsl:when test="$id = 'wdr5'">http://www1.wdr.de/resources/img/wdr/logo/epgmodule/wdr5_logo.svg</xsl:when>
      <xsl:when test="$id = 'radiofabrik'">https://upload.wikimedia.org/wikipedia/commons/3/31/Rf_logo2008badge.svg</xsl:when>
    -->
      <xsl:otherwise>../../../../<xsl:value-of select="$id"/>/app/logo.svg</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/rec:broadcast">
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
        <link href="../../../../../assets/bootstrap.min.css" rel="stylesheet" type="text/css"/>
        <link href="../../../app/style.css" rel="stylesheet" type="text/css"/>
        <style type="text/css">
#allday {
  font-size: 9pt;
}
        </style>
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
      <body id="broadcast" class="vevent">
        <noscript><p>JavaScript ist aus, es geht zwar (fast) alles auch ohne, aber mit ist's <b>schöner</b>. (Datumsformatierung, Aufnahmen wieder stornieren, Tagesübersicht, RDF Urls in der Fußzeile)</p></noscript>
        <ul id="whatsonnow" class="buttongroup">
          <xsl:for-each select="$now_fellows_xml/*/rec:broadcast">
            <xsl:variable name="fellow_station_name" select="substring-before(rec:meta[@name='DC.identifier']/@content, '/')"/>
            <li id="station_{$fellow_station_name}"><a href="../../../../{rec:meta[@name='DC.identifier']/@content}">
              <span class="station"><xsl:value-of select="$fellow_station_name"/></span><xsl:text> </xsl:text>
              <!-- safari doesn't like that:
              <xsl:variable name="station_logo">
                <xsl:call-template name="station_logo"><xsl:with-param name="id" select="$fellow_station_name"/></xsl:call-template>
              </xsl:variable>
              <img style="max-height:1.7ex;max-width:15ex" alt="" src="{$station_logo}"/>
              -->
              <br class='br'/>
              <span class="broadcast"><xsl:value-of select="rec:meta[@name='DC.title']/@content"/></span>
            </a></li>
          </xsl:for-each>
        </ul>
        <ul id="navigation" class="buttongroup" title="Navigation">
          <li><a id="prev_week" href="../../../../../app/now.lua?t=P-7D" title="Woche vorher">&lt;&lt;&lt;<br class="br"/><span>-1W</span></a></li>
          <li><a id="yesterday" href="../../../../../app/now.lua?t=P-1D" title="Tag vorher">&lt;&lt;<br class="br"/><span>-1D</span></a></li>
          <li><a href="../../../../../app/prev.lua" rel="prev" title="Sendung vorher">&lt;</a></li>
          <li class="now"><a href="../../../now">aktuell</a></li>
          <li><a href="../../../../../app/next.lua" rel="next" title="Sendung nachher">&gt;</a></li>
          <li><a id="tomorrow" href="../../../../../app/now.lua?t=P1D" title="Tag nachher">&gt;&gt;<br class="br"/><span>+1D</span></a></li>
          <li><a id="next_week" href="../../../../../app/now.lua?t=P7D" title="Woche nachher">&gt;&gt;&gt;<br class="br"/><span>+1W</span></a></li>
        </ul>
        <div class="summary">
          <h2 id="series">
            <xsl:value-of select="rec:meta[@name='DC.title.series']/@content"/>
          </h2><xsl:text> </xsl:text>
          <h1 id="title">
            <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
          </h1>
        </div>
          <h2 id="summary">
            <xsl:value-of select="rec:meta[@name='DC.title.episode']/@content"/>
          </h2>
        <p>
          <xsl:call-template name="broadcast_station_source"/>
          <xsl:call-template name="station_rdf_logo"/>
          <xsl:call-template name="station_rdf_stream"/>
        </p>
        <h3 id="date">
          <span id="dtstart" class="dtstart moment_date_time" title="{rec:meta[@name='DC.format.timestart']/@content}"><xsl:value-of select="translate(rec:meta[@name='DC.format.timestart']/@content, 'T', ' ')"/></span>
          bis
          <span id="dtend" class="dtend moment_time" title="{rec:meta[@name='DC.format.timeend']/@content}"><xsl:value-of select="substring-after(rec:meta[@name='DC.format.timeend']/@content, 'T')"/></span>
        </h3>
        <p class="image">
          <img alt="Bild zur Sendung" id="image" class="border animated fadeInRotate" src="{rec:meta[@name='DC.image']/@content}"/>
        </p>
        <div id="content" class="description border">
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
          <a id="enclosure_link">✇ mp3</a>
        </p>
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
          Powered by <a href="http://purl.mro.name/recorder">github.com/mro/internet-radio-recorder</a><br class="br"/>
          <a href="http://www.w3.org/RDF/">RDF</a>:<br class="br"/>
          <tt>$ <a href="http://librdf.org/raptor/rapper.html">rapper</a> -i grddl -o turtle '<span class="canonical-url url">&lt;url from address bar&gt;</span>'</tt><br class="br"/>
          <tt>$ <a href="http://librdf.org/raptor/rapper.html">rapper</a> -i grddl -o rdfxml-abbrev '<span class="canonical-url">&lt;url from address bar&gt;</span>'</tt><br class="br"/>
          <tt>$ <a href="http://xmlsoft.org/XSLT/xsltproc.html">xsltproc</a> --stringparam canonical_url '<span class="canonical-url">&lt;url from address bar&gt;</span>' '<span class="base-url">&lt;url from address bar&gt;/../../../../../..</span>/assets/2013/broadcast2rdf.xslt' '<span class="canonical-url">&lt;url from address bar&gt;</span>.xml'</tt>
        </p>
        <script type="text/javascript" src="../../../../../assets/jquery-3.1.0.min.js"/>
        <script type="text/javascript" src="../../../../../assets/moment-2.14.1.min.js"/><!-- http://momentjs.com/ -->
        <script type="text/javascript" src="../../../../../assets/lang/de.js"/><!-- https://github.com/timrwood/moment/blob/develop/min/lang/de.js -->
        <script type="text/javascript" src="../../../../../assets/broadcast2html.js" />
      </body>
    </html>
  </xsl:template>

  <xsl:template name="bs-icon">
    <!-- http://danklammer.com/articles/svg-stroke-ftw/#give-it-a-spin -->
    <xsl:param name="name"/>
    <svg:svg class="bs-icon" viewBox="0 0 32 32">
      <svg:use xlink:href="../../../../../assets/bytesize-symbols.min.svg#{$name}"/>
    </svg:svg>
  </xsl:template>

  <xsl:template name="i-backwards"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-backwards</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-caret-left"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-caret-left</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-start"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-start</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-end"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-end</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-caret-right"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-caret-right</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-forwards"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-forwards</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-volume"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-volume</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-play"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-play</xsl:with-param></xsl:call-template></xsl:template>
  <xsl:template name="i-close"><xsl:call-template name="bs-icon"><xsl:with-param name="name">i-close</xsl:with-param></xsl:call-template></xsl:template>

  <xsl:template match="/rec:broadcasts">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="{rec:broadcast[1]/rec:meta[@name='DC.language']/@content}">
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
        <link rel="profile" href="http://microformats.org/profile/hcalendar"/>

        <link href="../../../../../assets/bootstrap.min.css" rel="stylesheet" type="text/css"/>
        <!-- link href="../../../app/style.css" rel="stylesheet" type="text/css"/ -->
        <style type="text/css"><!-- both write <![CDATA[ to output and keep this content here safe: -->
/*&lt;![CDATA[<![CDATA[*/
.broadcast img {  
  width: 40%;
}
#broadcasts li {
  border-bottom: 1px solid #888;
}
a.glyphicon {
  width: 2ex;
}
a.glyphicon-play {
  color: red;
}
.text-capitalize {
  font-variant: small-caps;
}
.bs-icon {
  width           : 3ex;
  /* http://danklammer.com/bytesize-icons/ */
  height          : 16px;
  fill            : none;
  stroke          : #337ab7;
  stroke-width    : 5px;
  stroke-linejoin : round;
  overflow        : visible;
  display         : none;
}
#overview > li.selected::before {
	content: '· ';
}

/* This is a workaround for Browsers that insert additional <br> tags.
 * See http://purl.mro.name/safari-xslt-br-bug */
br    { display:none; }
br.br { display:inline; }

/*]]>]]&gt;*/
        </style>
        <title><xsl:value-of select="@date"/> foobar</title>
      </head>
      <body>
        <div class="container">

          <noscript><p>JavaScript ist aus, es geht zwar (fast) alles auch ohne, aber mit ist's <b>schöner</b>. (Zeitgleiche Sendungen anderer Sender, Datumsformatierung, Aufnahmen wieder stornieren, Tagesübersicht, RDF Url)</p></noscript>

          <h1 title="{@date}">
            <span id="date" class="moment_date" title="{@date}"><xsl:value-of select="@date"/></span><xsl:text> </xsl:text>
            <span id="station_logo"><xsl:call-template name="station_rdf_logo"/></span><xsl:text> </xsl:text>
            <small id="station_stream"><xsl:call-template name="station_rdf_stream"/></small>
          </h1>

          <ol id="broadcasts" class="list-unstyled">
            <xsl:for-each select="rec:broadcast">
              <xsl:variable name="dtstart" select="rec:meta[@name='DC.format.timestart']/@content"/>
              <xsl:variable name="rowid" select="translate(substring($dtstart, 11, 6), ':', '')"/>
              <xsl:variable name="duration_minutes" select="number(rec:meta[@name='DC.format.duration']/@content) div 60"/>

              <li class="broadcast vevent is_past clearfix" id="{$rowid}">

                <h4 class="pull-right">
                  <a title="Woche vorher" href="../../../../../app/now.lua?t={$dtstart}P-7D" class="glyphicon glyphicon-fast-backward"/>
                  <a title="Tag vorher" href="../../../../../app/now.lua?t={$dtstart}P-1D" class="glyphicon glyphicon-step-backward"/>
                  <xsl:variable name="prev_rowid" select="translate(substring(preceding-sibling::rec:broadcast[1]/rec:meta[@name='DC.format.timestart']/@content, 11, 6), ':', '')"/>
                  <xsl:choose>
                  	<xsl:when test="$prev_rowid"><a title="Sendung vorher" href="index#{$prev_rowid}" class="glyphicon glyphicon-chevron-left"/></xsl:when>
                  	<xsl:otherwise><a title="Sendung vorher" class="text-muted glyphicon glyphicon-chevron-left"/></xsl:otherwise>
                  </xsl:choose>
                  <span style="display:none">
                    <a class="dtstart moment_time" href="index#{$rowid}" title="{rec:meta[@name='DC.format.timestart']/@content}"><xsl:value-of select="substring(rec:meta[@name='DC.format.timestart']/@content, 12, 5)"/></a>
                    bis
                    <a class="dtend moment_time" title="{rec:meta[@name='DC.format.timeend']/@content}"><xsl:value-of select="substring(rec:meta[@name='DC.format.timeend']/@content, 12, 5)"/></a>
                  </span>
                  <xsl:variable name="next_rowid" select="translate(substring(following-sibling::rec:broadcast[1]/rec:meta[@name='DC.format.timestart']/@content, 11, 6), ':', '')"/>
                  <xsl:choose>
                  	<xsl:when test="$next_rowid"><a title="Sendung nachher" href="index#{$next_rowid}" class="glyphicon glyphicon-chevron-right"/></xsl:when>
                  	<xsl:otherwise><a title="Sendung nachher" class="text-muted glyphicon glyphicon-chevron-right"/></xsl:otherwise>
                  </xsl:choose>
                  <a title="Tag nachher" href="../../../../../app/now.lua?t={$dtstart}P+1D" class="glyphicon glyphicon-step-forward"/>
                  <a title="Woche nachher" href="../../../../../app/now.lua?t={$dtstart}P+7D" class="glyphicon glyphicon-fast-forward"/>
                </h4>

                <h4 class="clearfix">
                  <a class="dtstart moment_time" href="index#{$rowid}" title="{rec:meta[@name='DC.format.timestart']/@content}"><xsl:value-of select="substring(rec:meta[@name='DC.format.timestart']/@content, 12, 5)"/></a>
                  bis
                  <a class="dtend moment_time" title="{rec:meta[@name='DC.format.timeend']/@content}"><xsl:value-of select="substring(rec:meta[@name='DC.format.timeend']/@content, 12, 5)"/></a>:
                </h4>

                <p class="image">
                  <a title="Original Sendungsseite beim Sender" class="via" href="{rec:meta[@name='DC.source']/@content}" rel="via">
                    <img alt="Original Sendungsseite beim Sender" class="img-responsive pull-right" src="{rec:meta[@name='DC.image']/@content}"/>
                  </a>
                </p>

                <xsl:if test="rec:meta[@name='DC.title.series']/@content">
                  <h3 class="series"><xsl:value-of select="rec:meta[@name='DC.title.series']/@content"/></h3>
                </xsl:if>

                <h2 class="summary"><xsl:value-of select="rec:meta[@name='DC.title']/@content"/></h2>

                <xsl:if test="rec:meta[@name='DC.title.episode']/@content">
                  <h3 class="episode"><xsl:value-of select="rec:meta[@name='DC.title.episode']/@content"/></h3>
                </xsl:if>
                <p class="description border detect-urls">
                  <xsl:call-template name="linefeed2br">
                    <xsl:with-param name="string" select="rec:meta[@name='DC.description']/@content"/>
                  </xsl:call-template>
                </p>

                <h3>Aufnahme</h3>
                <p style="display:none" class="podcasts">keiner</p>
                <p class="enclosure">
                  <!-- audio controls="controls" style="display:none">Doesn't play well with auth...<source type="audio/mpeg" /></audio -->
                  <a title="Abspielen" class="glyphicon glyphicon-headphones"/>
                  <a title="Aufnehmen" class="glyphicon glyphicon-play"/>
                  <a title="Nicht Aufnehmen" class="glyphicon glyphicon-stop"/>

                  <a title="Play" class="enclosure_link" href="../../../../../enclosures/{rec:meta[@name='DC.identifier']/@content}.mp3">
                    ✇ mp3
                  </a>
                </p>
              </li>
            </xsl:for-each>
          </ol>

          <ol id="overview" class="hidden list-unstyled small">
            <li class="is_past"><a href="#">Alle aufklappen</a></li>
            <!-- TODO: aktuell ? -->
            <xsl:for-each select="rec:broadcast">
              <xsl:variable name="rowid" select="translate(substring(rec:meta[@name='DC.format.timestart']/@content, 11, 6), ':', '')"/>
              <li class="broadcast is_past" id="mini_{$rowid}">
                <a href="#{$rowid}">
                  <xsl:value-of select="substring(rec:meta[@name='DC.format.timestart']/@content, 12, 5)"/>
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
                </a>
              </li>
            </xsl:for-each>
          </ol>

          <hr/>

          <h2 id="stations">Aktuell auf anderen Sendern</h2>
          <table>
            <tbody>
              <xsl:for-each select="$now_fellows_xml/*/rec:broadcast">
                <xsl:variable name="fellow_station_name" select="substring-before(rec:meta[@name='DC.identifier']/@content, '/')"/>
                <tr id="station_{$fellow_station_name}">
                  <td class="text-capitalize"><xsl:value-of select="$fellow_station_name"/></td>
                  <td class="text-right">
                    <!-- safari doesn't like that: -->
                    <!-- xsl:variable name="station_logo">
                      <xsl:call-template name="station_logo"><xsl:with-param name="id" select="$fellow_station_name"/></xsl:call-template>
                    </xsl:variable -->
                    <img style="max-height:2.7ex;max-width:15ex;" alt="" src="../../../../{$fellow_station_name}/app/logo.svg"/>
                  </td>
                  <td>
                    <a href="../../../../{rec:meta[@name='DC.identifier']/@content}">
                      <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
                    </a>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>

          <hr/>

          <p id="footer" class="small">
            <!--
            <a style="display:none" href="http://validator.w3.org/check?uri=referer">
            <img alt="Valid XHTML 1.0 Strict" height="31" src="http://www.w3.org/Icons/valid-xhtml10-blue.png" width="88"/>
            </a>
            <a style="display:none" href="http://jigsaw.w3.org/css-validator/check/referer?profile=css3&amp;usermedium=screen&amp;warning=2&amp;vextwarning=false&amp;lang=de">
            <img alt="CSS ist valide!" src="http://jigsaw.w3.org/css-validator/images/vcss-blue" style="border:0;width:88px;height:31px"/>
            </a>
            -->
            Powered by <a href="http://purl.mro.name/recorder">github.com/mro/internet-radio-recorder</a>,
            Icons from <a href="http://danklammer.com/bytesize-icons/">Bytesize</a>,
            <a href="http://getbootstrap.com/components/#glyphicons">Glyphicons</a> and
            <a href="http://fontawesome.io/">Font Awesome</a>.<br class="br"/>
            <a href="http://www.w3.org/RDF/">RDF</a>:<br class="br"/>
            <tt>$ url='<span class="canonical-url">&lt;url from address bar&gt;</span>' ; curl "${url}" | gunzip | <a href="http://librdf.org/raptor/rapper.html">rapper</a> -i grddl -o turtle - "${url}"</tt><br class="br"/>
            <tt>$ url='<span class="canonical-url">&lt;url from address bar&gt;</span>' ; curl "${url}" | gunzip | <a href="http://librdf.org/raptor/rapper.html">rapper</a> -i grddl -o rdfxml-abbrev - "${url}"</tt><br class="br"/>
            <tt>$ url='<span class="canonical-url">&lt;url from address bar&gt;</span>' ; <a href="http://xmlsoft.org/XSLT/xsltproc.html">xsltproc</a> --stringparam canonical_url "${url}" '<span class="base-url">&lt;url from address bar&gt;/../../../../../..</span>/assets/2013/broadcast2rdf.xslt' "${url}"</tt>
          </p>

        </div><xsl:comment> /container </xsl:comment>

        <script type="text/javascript" src="../../../../../assets/jquery-3.1.0.min.js"/>
        <script type="text/javascript" src="../../../../../assets/moment-2.14.1.min.js"/><!-- http://momentjs.com/ -->
        <script type="text/javascript" src="../../../../../assets/lang/de.js"/><!-- https://github.com/timrwood/moment/blob/develop/min/lang/de.js -->
        <script type="text/javascript" src="../../../../../assets/broadcast2html.js" />
        <script type="text/javascript">
// <![CDATA[

// deprecated. Expand time-links
$('ol > li > h4 > a[href^="../../../../../app/now.lua?t="]').attr('href', function(i, value) {
  var tMatch = value.match(/\?t=(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})?P\+?(-?\d+)D$/);
  return '../../../' + moment(tMatch[1]).add(tMatch[2], 'days').format('YYYY/MM/DD/[index#T]HHmm');
});

$('.detect-urls').html(function(i, value) { return amendClickableURLsInHTML(value); });

function updateForTimeHash(has) {
  $('#broadcasts li.broadcast').toggleClass('hidden', true);
  $('#broadcasts li' + has).toggleClass('hidden', false);

  $('#overview li > a').toggleClass('bg-primary', false);
  $('#mini_' + has.replace('#','') + ' > a').toggleClass('bg-primary', true);

  // looks stupid but forces scroll (on Firefox):
  location.hash = has;
}
window.onhashchange = function(){ updateForTimeHash(location.hash); };
/*
  http://stackoverflow.com/questions/265774/programmatically-scroll-to-an-anchor-tag
  document.getElementById('MyID').scrollIntoView(true)
*/
window.addEventListener("DOMContentLoaded", function(event) {
  $('#overview').toggleClass('hidden', false);
  updateForTimeHash(location.hash);
});

//]]>
</script>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
