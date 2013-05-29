<?xml version="1.0" encoding="UTF-8"?>
<!--
  Turn broadcast xml into html, used client-side, by the browser.

  Supposed to be either linked to from or located in station/<name>/app/broadcast2html.xslt,
  so each station could provide a custom skin.
-->
<xsl:stylesheet xmlns:rec="https://raw.github.com/mro/radio-pi/master/htdocs/app/pbmi2003-recmod2012/broadcast.rnc" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/1999/xhtml" version="1.0">
  <xsl:output method="html" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"/>
  <xsl:template match="rec:broadcast">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="{rec:meta[@name='DC.language']/@content}">
      <head>
        <meta content="text/html; charset=utf-8" http-equiv="content-type"/>
        <meta name="viewport" content="width=device-width"/>
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
        <ul class="navigation">
          <li id="link_now">
            <a href="../../../now">↻ aktuelle Sendung</a>
          </li>
          <li id="link_parent">
            <a href="index.html" rel="parent">↑ ganzer Tag</a>
          </li>
          <li id="link_prev">
            <a href="../../../../../app/prev.lua" rel="prev">← vorige Sendung</a>
          </li>
          <li id="link_next">
            <a href="../../../../../app/next.lua" rel="next">→ nächste Sendung</a>
          </li>
        </ul>
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
          <a id="via" class="via" href="{rec:meta[@name='DC.source']/@content}" rel="via">www.br.de</a>,
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
          <xsl:value-of select="rec:meta[@name='DC.description']/@content"/>
        </div>
        <h3>Podcast</h3>
        <p id="podcasts" class="podcasts">keiner</p>
        <form id="ad_hoc" method="post" action="../../../../../enclosures/app/ad_hoc.lua">
          <fieldset>
          <input id="ad_hoc_action" type="hidden" name="add" value="referer"/>
          <input id="ad_hoc_submit" type="submit" value="Aufnehmen"/>
          </fieldset>
        </form>
        <p id="enclosure">
          <!-- audio controls="controls" style="display:none">Doesn't play well with auth...<source type="audio/mpeg" /></audio -->
          <a id="enclosure_link">mp3</a></p>
        <hr/>
        <ul id="allday" class="nobullet" style="display:none"></ul>
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
          Powered by <a href="https://github.com/mro/radio-pi">github.com/mro/radio-pi</a>
        </p>
        <noscript>Script ist aus!</noscript>
        <script type="text/javascript" src="../../../../../assets/jquery-2.0.0.min.js"/>
        <script type="text/javascript" src="../../../../../assets/moment.min.js"/><!-- http://momentjs.com/ -->
        <script type="text/javascript" src="../../../../../assets/lang/de.js"/><!-- https://github.com/timrwood/moment/blob/develop/min/lang/de.js -->
        <script type="text/javascript" src="../../../../../assets/broadcast2html.js" />
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
