// Copyright (c) 2015-2017 Marcus Rohrmoser, https://github.com/mro/radio-pi
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
// associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// MIT License http://opensource.org/licenses/MIT

// http://golang.org/pkg/testing/
// http://blog.stretchr.com/2014/03/05/test-driven-development-specifically-in-golang/
// https://xivilization.net/~marek/blog/2015/05/04/go-1-dot-4-2-for-raspberry-pi/

package main

import (
	"bytes"
	"encoding/xml"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestBroadcastFromXmlFileName(t *testing.T) {
	td, err := broadcastFromXmlFileName("")
	assert.Equal(t, "open : no such file or directory", err.Error(), "soso")

	td, err = broadcastFromXmlFileName("testdata/b2-2016-08-25-1805.xml")
	assert.Nil(t, err, "soso")
	assert.Equal(t, "Bayern 2-radioMusik", td.title, "aha")
	assert.Equal(t, "b2/2016/08/25/1805 Bayern 2-radioMusik", td.identifier, "aha")
	assert.Equal(t, "de", td.language, "aha")
	assert.Equal(t, "/app/pbmi2003-recmod2012/", td.scheme, "aha")
	assert.Equal(t, "anspruchsvoll - entspannt - weltoffen", td.title_episode, "aha")
	assert.Equal(t, "", td.title_series, "aha")
	assert.Equal(t, "http://www.br.de/radio/bayern2/musik/bayern2-radiomusik/index.html", td.subject, "aha")
	assert.Equal(t, "2016-08-25T18:05:00+02:00", td.format_timestart.Format(time.RFC3339), "aha")
	assert.Equal(t, "2016-08-25T18:30:00+02:00", td.format_timeend.Format(time.RFC3339), "aha")
	assert.Equal(t, int16(1500), td.format_duration, "aha")
	assert.Equal(t, "http://www.br.de/radio/bayern2/musik/bayern2-radiomusik/rebekka-bakken-102~_v-img__16__9__m_-4423061158a17f4152aef84861ed0243214ae6e7.jpg?version=64958", td.image.String(), "aha")
	assert.Equal(t, "anspruchsvoll - entspannt - weltoffen\nMit Riegler Hias feat. D'Hundskrippln, Rebekka Bakken, Randy Newman und vielen mehr\nModeration: Thomas Mehringer", td.description, "aha")
	assert.Equal(t, "Bayerischer Rundfunk", td.author, "aha")
	assert.Equal(t, "http://www.br.de/radio/bayern2/programmkalender/ausstrahlung-772436.html", td.source.String(), "aha")
}

func TestXmlEncoding(t *testing.T) {
	x := broadcastXml{
		Language: "de",
		Meta: []xmlEntry{
			xmlEntry{
				Name:    "Foo",
				Content: "bar",
			},
		},
	}
	buf := new(bytes.Buffer)
	err := xml.NewEncoder(buf).Encode(x)
	assert.Nil(t, err, "jaja")
	assert.Equal(t, "<broadcast xmlns=\"../../../../../assets/2013/radio-pi.rdf\" xml:lang=\"de\"><meta name=\"Foo\" content=\"bar\"></meta></broadcast>", buf.String(), "echt?")
}
