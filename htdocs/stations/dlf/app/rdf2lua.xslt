<?xml version="1.0" encoding="UTF-8"?>
<!--
    turn broadcast rdf into lua tables

    $ xsltproc rdf2lua.xslt ....rdf

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
  
  <xsl:template match="/rdf:RDF">
    <xsl:apply-templates select="rdf:Description" />
  </xsl:template>

  <xsl:template match="rdf:Description">
-- comma separated lua tables, one per broadcast:
{
		DC_language = '<xsl:value-of select="dcterms:language" />',
		DC_title = '<xsl:call-template name="string-to-lua"><xsl:with-param name="text" select="dcterms:title" /></xsl:call-template>',
		DC_copyright = '<xsl:call-template name="string-to-lua"><xsl:with-param name="text" select="dcterms:copyright" /></xsl:call-template>',
		DC_last_modified = '<xsl:value-of select="dcterms:last-modified" />',
		DC_format_timestart = '<xsl:value-of select="dcterms:date" />',
		DC_format_timeend = 'computed by broadcast-amend.lua assuming schedule starting 00:00',
		DC_relation = '<xsl:value-of select="dcterms:relation/@rdf:resource" />',
		DC_description = '<xsl:call-template name="string-to-lua"><xsl:with-param name="text" select="dcterms:description" /></xsl:call-template>',
},
  </xsl:template>

  <!-- http://stackoverflow.com/a/3067130 -->
	<xsl:template name="string-to-lua">
		<xsl:param name="text" />
		<xsl:variable name="text0">
			<xsl:call-template name="string-replace-all">
				<xsl:with-param name="text" select="$text"/>
				<xsl:with-param name="replace">\</xsl:with-param>
				<xsl:with-param name="by">\\</xsl:with-param>
			</xsl:call-template>
		</xsl:variable>
		<xsl:variable name="text1">
			<xsl:call-template name="string-replace-all">
				<xsl:with-param name="text" select="$text0"/>
				<xsl:with-param name="replace" select="string('&#10;')" />
				<xsl:with-param name="by">\n</xsl:with-param>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="string-replace-all">
    	<xsl:with-param name="text" select="$text1" />
    	<xsl:with-param name="replace">'</xsl:with-param>
    	<xsl:with-param name="by">\'</xsl:with-param>
  	</xsl:call-template>
	</xsl:template>
  
  <!-- http://stackoverflow.com/a/3067130 -->
	<xsl:template name="string-replace-all">
		<xsl:param name="text" />
		<xsl:param name="replace" />
		<xsl:param name="by" />
		<xsl:choose>
			<xsl:when test="contains($text, $replace)">
				<xsl:value-of select="substring-before($text,$replace)" />
				<xsl:value-of select="$by" />
				<xsl:call-template name="string-replace-all">
					<xsl:with-param name="text"
					select="substring-after($text,$replace)" />
					<xsl:with-param name="replace" select="$replace" />
					<xsl:with-param name="by" select="$by" />
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$text" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
  
</xsl:stylesheet>
<!--
      dst << "- - comma separated lua tables, one per broadcast:\n"
      dst << "{\n"
      kv_to_lua(:t_download_start, t_download_start.to_f, dst) unless t_download_start.nil?
      kv_to_lua(:t_scrape_start, t_scrape_start.to_f, dst) unless t_scrape_start.nil?
      kv_to_lua(:t_scrape_end, t_scrape_end.to_f, dst) unless t_scrape_end.nil?

      kv_to_lua :station, station.name, dst
      kv_to_lua :title, title, dst
      kv_to_lua :DC_scheme, '/app/pbmi2003-recmod2012/', dst
      kv_to_lua :DC_language, self.DC_language, dst
      kv_to_lua(:DC_title, self.DC_title.nil? ? title : self.DC_title, dst)
      kv_to_lua :DC_title_series, self.DC_title_series, dst
      kv_to_lua :DC_title_episode, self.DC_title_episode, dst
      kv_to_lua(:DC_format_timestart, self.DC_format_timestart.nil? ? dtstart : self.DC_format_timestart, dst)
      kv_to_lua :DC_format_timeend, self.DC_format_timeend, dst
      kv_to_lua :DC_format_duration, self.DC_format_duration, dst
      kv_to_lua :DC_image, self.DC_image, dst
      kv_to_lua :DC_description, self.DC_description, dst
      kv_to_lua :DC_author, self.DC_author, dst
      kv_to_lua :DC_publisher, self.DC_publisher, dst
      kv_to_lua :DC_creator, self.DC_creator, dst
      kv_to_lua :DC_copyright, self.DC_copyright, dst
      kv_to_lua :DC_source, self.src_url, dst
      dst << "},\n"
      dst << "\n"
-->