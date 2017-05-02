// Copyright (c) 2015-2017 Marcus Rohrmoser, http://purl.mro.name/recorder
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

package main

import (
	"encoding/xml"
	"io"
	"net/url"
	"os"
	"strconv"
	"time"
)

type broadcast struct {
	title            string
	identifier       string
	language         string
	scheme           string
	titleEpisode    string
	titleSeries     string
	subject          string
	formatTimeStart time.Time
	formatTimeEnd   time.Time
	formatDuration  int16
	image            url.URL
	description      string
	author           string
	publisher        string
	source           url.URL
}

func broadcastFromXmlFileName(xmlFileName string) (broadcast, error) {
	r, err := os.Open(xmlFileName)
	if nil != err {
		return broadcast{}, err
	}
	defer r.Close()
	return broadcastFromXmlReader(r)
}

func broadcastFromXmlReader(xmlFile io.Reader) (broadcast, error) {
	x := broadcastXml{}
	err := xml.NewDecoder(xmlFile).Decode(&x)
	if nil != err {
		return broadcast{}, err
	}
	t := broadcast{}
	for _, row := range x.Meta {
		switch row.Name {
		case "DC.title":
			t.title = row.Content
		case "DC.identifier":
			t.identifier = row.Content
		case "DC.scheme":
			t.scheme = row.Content
		case "DC.language":
			t.language = row.Content
		case "DC.title.episode":
			t.titleEpisode = row.Content
		case "DC.title.series":
			t.titleSeries = row.Content
		case "DC.subject":
			t.subject = row.Content
		case "DC.format.timestart":
			tt, err := time.Parse(time.RFC3339, row.Content)
			if nil != err {
				return t, err
			}
			t.formatTimeStart = tt
		case "DC.format.timeend":
			tt, err := time.Parse(time.RFC3339, row.Content)
			if nil != err {
				return t, err
			}
			t.formatTimeEnd = tt
		case "DC.format.duration":
			i, err := strconv.Atoi(row.Content)
			if nil != err {
				return t, err
			}
			t.formatDuration = int16(i)
		case "DC.image":
			u, err := url.Parse(row.Content)
			if nil != err {
				return t, err
			}
			t.image = *u
		case "DC.description":
			t.description = row.Content
		case "DC.publisher":
			t.publisher = row.Content
		case "DC.author":
			t.author = row.Content
		case "DC.source":
			u, err := url.Parse(row.Content)
			if nil != err {
				return t, err
			}
			t.source = *u
		default:
			panic("other field " + row.Name)
		}
	}
	return t, nil
}

type xmlEntry struct {
	Name    string `xml:"name,attr"`
	Content string `xml:"content,attr"`
}

type broadcastXml struct {
	XMLName  xml.Name   `xml:"../../../../../assets/2013/radio-pi.rdf broadcast"`
	Language string     `xml:"xml:lang,attr"`
	Meta     []xmlEntry `xml:"meta"`
}
