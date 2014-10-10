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
<!--
 Extract schedule base url from about.rdf.
-->
<xsl:stylesheet
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dcmit="http://purl.org/dc/dcmitype/"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:rec="http://purl.mro.name/recorder/2014/"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0">
  <xsl:output method="text"/>
  <xsl:template match="/">
    <xsl:for-each select="rdf:RDF/dcmit:Text[
    	rec:curfew/@rdf:datatype = 'http://www.w3.org/2001/XMLSchema#time'
    	and dct:format/@rdf:resource = 'http://purl.org/NET/mediatypes/text/html'
    ]/@rdf:about">
      <xsl:value-of select="."/>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
