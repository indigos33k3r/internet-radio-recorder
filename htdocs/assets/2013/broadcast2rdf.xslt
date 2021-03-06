<?xml version="1.0" encoding="UTF-8"?>
<!--

  Copyright (c) 2015 Marcus Rohrmoser, http://purl.mro.name/recorder

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

  Turn broadcast xml into rdf

  built following http://www.w3.org/TR/grddl-tests/#sq2
  like http://www.w3.org/2001/sw/grddl-wg/td/sq1t.xsl
  
  http://wiki.dublincore.org/index.php/User_Guide/Publishing_Metadata#dcterms:date
  Literals & Languages: http://www.w3.org/TR/rdf11-concepts/#section-Graph-Literal
  
  http://www.w3.org/TR/xslt/
-->
<xsl:stylesheet
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3schools.com/RDF/rdf-schema.xml"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
  xmlns:xdt="http://www.w3.org/2005/xpath-datatypes#"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:dctype="http://purl.org/dc/dcmitype/"
  xmlns:freq="http://purl.org/cld/freq/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:tl="http://purl.org/NET/c4dm/timeline.owl#"
  xmlns:iso639-1="http://lexvo.org/id/iso639-1/"
  xmlns:mime="http://purl.org/NET/mediatypes/"
  xmlns:rec="../../../../../assets/2013/radio-pi.rdf"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:ebu="http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="rec ebu"
  version="1.0">
  <xsl:output method="xml"/>

  <xsl:param name="canonical_url"></xsl:param>

  <!-- http://skew.org/xml/stylesheets/url-encode/url-encode.xsl via http://stackoverflow.com/a/3518109 -->
  <xsl:template name="url-encode">
    <xsl:param name="str"/>
    <!-- Characters we'll support. We could add control chars 0-31 and 127-159, but we won't. -->
    <xsl:variable name="ascii"> !"#$%&amp;'()*+,-./0123456789:;&lt;=&gt;?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~</xsl:variable>
    <xsl:variable name="latin1">&#160;&#161;&#162;&#163;&#164;&#165;&#166;&#167;&#168;&#169;&#170;&#171;&#172;&#173;&#174;&#175;&#176;&#177;&#178;&#179;&#180;&#181;&#182;&#183;&#184;&#185;&#186;&#187;&#188;&#189;&#190;&#191;&#192;&#193;&#194;&#195;&#196;&#197;&#198;&#199;&#200;&#201;&#202;&#203;&#204;&#205;&#206;&#207;&#208;&#209;&#210;&#211;&#212;&#213;&#214;&#215;&#216;&#217;&#218;&#219;&#220;&#221;&#222;&#223;&#224;&#225;&#226;&#227;&#228;&#229;&#230;&#231;&#232;&#233;&#234;&#235;&#236;&#237;&#238;&#239;&#240;&#241;&#242;&#243;&#244;&#245;&#246;&#247;&#248;&#249;&#250;&#251;&#252;&#253;&#254;&#255;</xsl:variable>
    <!-- Characters that usually don't need to be escaped -->
    <!-- xsl:variable name="safe">!'()*-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~</xsl:variable -->
    <xsl:variable name="safe">/!'()*-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~</xsl:variable>
    <xsl:variable name="hex" >0123456789ABCDEF</xsl:variable>

    <xsl:if test="$str">
      <xsl:variable name="first-char" select="substring($str,1,1)"/>
      <xsl:choose>
        <xsl:when test="contains($safe,$first-char)">
          <xsl:value-of select="$first-char"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="codepoint">
            <xsl:choose>
              <xsl:when test="contains($ascii,$first-char)">
                <xsl:value-of select="string-length(substring-before($ascii,$first-char)) + 32"/>
              </xsl:when>
              <xsl:when test="contains($latin1,$first-char)">
                <xsl:value-of select="string-length(substring-before($latin1,$first-char)) + 160"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:message terminate="no">Warning: string contains a character that is out of range! Substituting "?".</xsl:message>
                <xsl:text>63</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
        <xsl:variable name="hex-digit1" select="substring($hex,floor($codepoint div 16) + 1,1)"/>
        <xsl:variable name="hex-digit2" select="substring($hex,$codepoint mod 16 + 1,1)"/>
        <xsl:value-of select="concat('%',$hex-digit1,$hex-digit2)"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="string-length($str) &gt; 1">
        <xsl:call-template name="url-encode">
          <xsl:with-param name="str" select="substring($str,2)"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template match="/">
    <rdf:RDF>
      <xsl:if test="$canonical_url"><xsl:attribute name="xml:base"><xsl:value-of select="$canonical_url"/></xsl:attribute></xsl:if>
      <xsl:apply-templates match="rec:broadcast|rec:broadcasts/rec:broadcast"/>
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="rec:broadcast">
    <!-- -->
    <xsl:variable name="identifier_encoded">
      <xsl:call-template name="url-encode">
        <xsl:with-param name="str" select="rec:meta[@name='DC.identifier']/@content"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="me_uri" select="concat('../../../../',$identifier_encoded)"/>
    <rdf:Description rdf:about="{$me_uri}" xml:lang="{rec:meta[@name='DC.language']/@content}">
      <rdfs:label>Sendung</rdfs:label>
      <rdfs:label xml:lang="en">broadcast</rdfs:label>
      <dct:identifier rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
        <xsl:value-of select="rec:meta[@name='DC.identifier']/@content"/>
      </dct:identifier>
      <dct:title>
        <xsl:value-of select="rec:meta[@name='DC.title']/@content"/>
      </dct:title>
      <xsl:for-each select="rec:meta[@name='DC.subject']/@content">
        <dct:subject resource="{.}"/>
        <dct:isPartOf resource="{.}"/>
      </xsl:for-each>
      <dct:rightsHolder><rdf:Description><foaf:name>
        <xsl:value-of select="rec:meta[@name='DC.copyright']/@content"/>
      </foaf:name></rdf:Description></dct:rightsHolder>
      <dct:creator><rdf:Description><foaf:name>
        <xsl:value-of select="rec:meta[@name='DC.author']/@content"/>
      </foaf:name></rdf:Description></dct:creator>
      <dct:abstract>
        <xsl:value-of select="rec:meta[@name='DC.description']/@content"/>
      </dct:abstract>
      <dct:temporal>
        <tl:Interval>
          <tl:start rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
            <xsl:value-of select="rec:meta[@name='DC.format.timestart']/@content"/>
          </tl:start>
          <tl:end rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
            <xsl:value-of select="rec:meta[@name='DC.format.timeend']/@content"/>
          </tl:end>
          <tl:durationXSD rdf:datatype="http://www.w3.org/2005/xpath-datatypes#dayTimeDuration"><!--
            -->PT<xsl:value-of select="format-number(rec:meta[@name='DC.format.duration']/@content,0)"/>S<!--
          --></tl:durationXSD>
          <tl:durationInt rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">
            <xsl:value-of select="format-number(rec:meta[@name='DC.format.duration']/@content,0)"/>
          </tl:durationInt>
          <tl:timeline rdf:resource="http://purl.org/NET/c4dm/timeline.owl#universaltimeline"/>
        </tl:Interval>
      </dct:temporal>
      <dct:references rdf:resource="{rec:meta[@name='DC.image']/@content}"/>
      <dct:language rdf:resource="http://lexvo.org/id/iso639-1/{rec:meta[@name='DC.language']/@content}"/>
      <dct:publisher><rdf:Description><foaf:name>
        <xsl:value-of select="rec:meta[@name='DC.publisher']/@content"/>
      </foaf:name></rdf:Description></dct:publisher>
      <dct:source rdf:resource="{rec:meta[@name='DC.source']/@content}"/>
      <dct:alternative>
        <xsl:value-of select="rec:meta[@name='DC.title.episode']/@content"/>
      </dct:alternative>
      <dc:titleSeries>
        <xsl:value-of select="rec:meta[@name='DC.title.series']/@content"/>
      </dc:titleSeries>
      <dct:hasFormat rdf:resource="../../../../../enclosures/{$identifier_encoded}.mp3"/>
      <dct:isPartOf rdf:resource="{$me_uri}/.."/>
      <!-- dct:references rdf:resource="../../../../../enclosures/"/ -->
      <!-- dct:references>hu
        <xsl:value-of select="base-uri('.')"/>
      </dct:references -->
        <!-- http://stackoverflow.com/questions/582957/get-file-name-using-xsl -->
        <!-- xsl:value-of select="system-property('xsl:version')"/ -->
        <!-- xsl:value-of select="base-uri()"/ -->
      <!-- dct:isPartOf rdf:resource="../../../../../podcasts/radiowelt/"/ -->
      <dct:isReferencedBy rdf:resource="../../../../modified.ttl"/>
    </rdf:Description>
    <xsl:if test="string-length(rec:meta[@name='DC.image']/@content) > 0">
      <dctype:StillImage rdf:about="{rec:meta[@name='DC.image']/@content}">
        <dct:format rdf:resource="http://purl.org/NET/mediatypes/image/jpeg"/>
        <dct:isReferencedBy rdf:resource="{$me_uri}"/>
      </dctype:StillImage>
    </xsl:if>
    <dctype:Sound rdf:about="../../../../../enclosures/{$identifier_encoded}.mp3">
      <rdfs:label xml:lang="de">mögliche Aufnahme</rdfs:label>
      <rdfs:label xml:lang="en">potential recording</rdfs:label>
      <dct:format rdf:resource="http://purl.org/NET/mediatypes/audio/mp3"/>
      <dct:isFormatOf rdf:resource="{$me_uri}"/>
    </dctype:Sound>
    <rdf:Description about="{$me_uri}/..">
      <rdfs:label xml:lang="de">Tag</rdfs:label>
      <rdfs:label xml:lang="en">day</rdfs:label>
      <dct:hasPart rdf:resource="{$me_uri}"/>
      <dct:isPartOf rdf:resource="{$me_uri}/../.."/>
      <dct:date rdf:datatype="http://www.w3.org/2001/XMLSchema#date">
        <xsl:value-of select="substring(rec:meta[@name='DC.format.timestart']/@content,1,10)"/>P1D<xsl:text/>
      </dct:date>
    </rdf:Description>
    <rdf:Description about="{$me_uri}/../..">
      <rdfs:label xml:lang="de">Monat</rdfs:label>
      <rdfs:label xml:lang="en">month</rdfs:label>
      <dct:hasPart rdf:resource="{$me_uri}/.."/>
      <dct:isPartOf rdf:resource="{$me_uri}/../.."/>
      <dct:date rdf:datatype="http://www.w3.org/2001/XMLSchema#date">
        <xsl:value-of select="substring(rec:meta[@name='DC.format.timestart']/@content,1,7)"/>-01P1M<xsl:text/>
      </dct:date>
    </rdf:Description>
    <rdf:Description about="{$me_uri}/../../..">
      <rdfs:label xml:lang="de">Jahr</rdfs:label>
      <rdfs:label xml:lang="en">year</rdfs:label>
      <dct:hasPart rdf:resource="{$me_uri}/../.."/>
      <dct:isPartOf rdf:resource="{$me_uri}/../../../.."/>
      <dct:date rdf:datatype="http://www.w3.org/2001/XMLSchema#date">
        <xsl:value-of select="substring(rec:meta[@name='DC.format.timestart']/@content,1,4)"/>-01-01P1Y<xsl:text/>
      </dct:date>
    </rdf:Description>
    <rdf:Description about="{$me_uri}/../../../..">
      <rdfs:label xml:lang="de">Sender</rdfs:label>
      <rdfs:label xml:lang="en">broadcasting station</rdfs:label>
      <dct:hasPart rdf:resource="{$me_uri}/../../.."/>
      <dct:isPartOf rdf:resource="{$me_uri}/../../../../.."/>
      <rdfs:isDefinedBy rdf:resource="{$me_uri}/../../../../about.rdf"/>
      <dct:relation rdf:resource="{$me_uri}/../../../../../modified.ttl"/>
    </rdf:Description>
    <foaf:Document about="{$me_uri}/../../../../about.rdf">
      <foaf:primaryTopic rdf:resource="{$me_uri}/../../../.."/>
    </foaf:Document>
    <rdf:Description about="{$me_uri}/../../../../..">
      <dct:hasPart rdf:resource="{$me_uri}/../../../.."/>
      <dct:isPartOf rdf:resource="{$me_uri}/../../../../../.."/>
    </rdf:Description>
    <rdf:Description about="{$me_uri}/../../../../../..">
      <rdfs:label xml:lang="de">Internet Radio Rekorder</rdfs:label>
      <rdfs:label xml:lang="en">Internet Radio Recorder</rdfs:label>
      <dct:relation rdf:resource="http://purl.mro.name/recorder/"/>
      <dct:hasPart rdf:resource="{$me_uri}/../../../../.."/>
      <!-- dct:hasPart rdf:resource="../../../../../podcasts/"/ -->
    </rdf:Description>
    <foaf:Document about="{$me_uri}/../../../../../modified.ttl">
      <rdfs:label xml:lang="de">aktualisierte Sendungen</rdfs:label>
      <rdfs:label xml:lang="en">updated broadcasts</rdfs:label>
      <dct:accrualPeriodicity>
        <rdf:Description about="http://purl.org/cld/freq/hourly">
          <rdfs:label xml:lang="de">stündlich</rdfs:label>
          <rdfs:label xml:lang="en">hourly</rdfs:label>
          <dct:extent>
            <xsl:comment>http://wiki.dublincore.org/index.php/User_Guide/Publishing_Metadata#dcterms:extent</xsl:comment>
            <rdf:Description about="http://purl.org/cld/freq/hourly/PT1H">
              <rdfs:label rdf:datatype="http://www.w3.org/2005/xpath-datatypes#dayTimeDuration">PT1H</rdfs:label>
            </rdf:Description>
          </dct:extent>
        </rdf:Description>
      </dct:accrualPeriodicity>
      <dct:references rdf:resource="{$me_uri}"/>
    </foaf:Document>

    <xsl:for-each select="rec:meta[@name='DC.subject']/@content">
      <dctype:Text about="{.}">
        <rdfs:label xml:lang="de">Sendereihe</rdfs:label>
        <rdfs:label xml:lang="en">Brand</rdfs:label>
        <dct:hasPart resource="{$me_uri}"/>
        <!-- dct:isReferencedBy resource=""/ -->
      </dctype:Text>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
