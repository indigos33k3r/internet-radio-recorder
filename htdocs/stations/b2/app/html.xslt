<?xml version="1.0" encoding="UTF-8"?>
<!--
  Copyright (c) 2013-2014 Marcus Rohrmoser, https://github.com/mro/radio-pi

  All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, are permitted
  provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice, this list of conditions
  and the following disclaimer.

  2. The software must not be used for military or intelligence or related purposes nor
  anything that's in conflict with human rights as declared in http://www.un.org/en/documents/udhr/ .

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-->
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:str="http://exslt.org/strings"
  xmlns:func="http://exslt.org/functions"
  extension-element-prefixes="func str"
  version="1.0">

  <!--
    Turn text/html markup to text/plain.
    
    Hijack the str: namespace.
  -->
  <func:function name="str:html2ascii">
    <xsl:param name="html" />
    <xsl:variable name="head" select="$html[position() = 1]"/>
    <xsl:variable name="tail" select="$html[position() > 1]"/>
    <func:result>
      <xsl:choose>
        <xsl:when test="0 = count($head)"/>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="'br' = name($head)">
              <xsl:text>&#10;<!-- linefeed --></xsl:text>
            </xsl:when>
            <xsl:when test="'p' = name($head)">
              <xsl:value-of select="str:html2ascii($head/node())"/>
              <xsl:if test="count($tail) > 0">
                <!-- omit trailing -->
                <xsl:text>&#10;&#10;<!-- double linefeed --></xsl:text>
              </xsl:if>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="normalize-space($head)"/>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:value-of select="str:html2ascii($tail)"/>
        </xsl:otherwise>
      </xsl:choose>    
    </func:result>
  </func:function>

</xsl:stylesheet>