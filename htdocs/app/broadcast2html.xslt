<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:rec="https://raw.github.com/mro/radio-pi/master/htdocs/app/pbmi2003-recmod2012/broadcast.rnc" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/1999/xhtml" version="1.0">
  <xsl:output method="xml" doctype-system="http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd" doctype-public="-//W3C//DTD XHTML 1.1//EN"/>
  <xsl:template match="rec:broadcast">
	<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="{rec:meta[@name='DC.language']/@content}">
	  <head>
		<meta content="text/html; charset=utf-8" http-equiv="content-type"/>
		<meta name="viewport" content="width=device-width"/>
		<link href="../../../../../app/favicon-32x32.png" rel="shortcut icon" type="image/png" />
		<link href="../../../../../app/favicon-512x512.png" rel="apple-touch-icon" type="image/png" />
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
			<a href="../../../../../app/now.lua">↻ aktuelle Sendung</a>
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
		<p class="via">
		  <a href="{rec:meta[@name='DC.source']/@content}" id="via" rel="via">www.br.de</a>
		</p>
		<p id="date"><span id="dtstart" title="{rec:meta[@name='DC.format.timestart']/@content}"><xsl:value-of select="rec:meta[@name='DC.format.timestart']/@content"/></span>
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
		<hr/>
		<p id="footer">
		  <a style="display:none" href="http://validator.w3.org/check?uri=referer">
			<img alt="Valid XHTML 1.0 Strict" height="31" src="http://www.w3.org/Icons/valid-xhtml10-blue.png" width="88"/>
		  </a>
		  <a style="display:none" href="http://jigsaw.w3.org/css-validator/check/referer?profile=css3&amp;usermedium=screen&amp;warning=2&amp;vextwarning=false&amp;lang=de">
			<img alt="CSS ist valide!" src="http://jigsaw.w3.org/css-validator/images/vcss-blue" style="border:0;width:88px;height:31px"/>
		  </a>
		  Powered by <a href="https://github.com/mro/radio-pi">github.com/mro/radio-pi</a>
		</p>
		<noscript>Script ist aus!</noscript>
		<script type="text/javascript" src="../../../../../app/jquery-1.9.1.min.js"/>
		<!-- script type="text/javascript" src="http://code.jquery.com/mobile/latest/jquery.mobile.min.js"/ -->
		<script type="text/javascript">
//<![CDATA[

function render_podcasts( data ) {
	var has_ad_hoc = false;
	var names = data.podcasts.map( function(pc) {
		if( pc.name == 'ad_hoc' )
			has_ad_hoc = true;
		return pc.name;
	} );
	$( '#podcasts' ).html( names.join(', ') );
	if( names.length == 0 ) {
		;
	} else if( has_ad_hoc ) {
		$( '#ad_hoc_action' ).attr('name', 'remove');
		$( '#ad_hoc_submit' ).attr('value', 'Nicht Aufnehmen');
	} else {
		$( '#ad_hoc_submit' ).attr('style', 'display:none;visibility:hidden');
	}
}
		var podasts_json_url = window.location.pathname.replace(/^.*\//,'').replace(/\.xml$/,'.json');
		$.ajax({
			url: podasts_json_url,
			cache: 'true',
			dataType: 'json',
			success: render_podcasts
		});

		$( '#dtstart' ).html( new Date( $("meta[name='DC.format.timestart']").attr("content") ).toLocaleString() );
		$( '#dtend' ).html( new Date( $("meta[name='DC.format.timeend']").attr("content") ).toLocaleTimeString() );
		var t = $("meta[name='DC.description']").attr("content");
		try {
			t = t.replace(/&/g, "&amp;");
			t = t.replace(/</g, "&lt;");
			t = t.replace(/>/g, "&gt;");
			t = t.replace(/\n/g, "\n<br/>\n");
			$( '#content' ).html( t );
		} catch(e) {
			$( '#content' ).text( 'Aua: "' + e + '": ' + t );
		}
  //]]>
  </script>
	  </body>
	</html>
  </xsl:template>
</xsl:stylesheet>
