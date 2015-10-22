// Copyright (c) 2015-2015 Marcus Rohrmoser, https://github.com/mro/radio-pi
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

package scrape // import "purl.mro.name/recorder/radio/scrape"

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"time"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

var _ = fmt.Printf

func urlMustParse(s string) *url.URL {
	ret, err := url.Parse(s)
	if nil != err {
		panic(err)
	}
	return ret
}

func StationBR(identifier string) *Station {
	switch identifier {
	case "b1":
		return &Station{Name: "Bayern 1", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern1/service/programm/index.html"), Identifier: identifier}
	case "b2":
		return &Station{Name: "Bayern 2", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern2/service/programm/index.html"), Identifier: identifier}
	case "b5":
		return &Station{Name: "Bayern 5", CloseDown: "06:00", ProgramURL: urlMustParse("http://www.br.de/radio/b5-aktuell/programmkalender/b5aktuell116.html"), Identifier: identifier}
	}
	return nil
}

/////////////////////////////////////////////////////////////////////////////
/// Find daily URLs
/////////////////////////////////////////////////////////////////////////////

var (
	urlDayRegExp *regexp.Regexp = regexp.MustCompile("^/radio/.+~_date-([0-9]{4}-[0-9]{2}-[0-9]{2})_-.+$")
)

func newTimeURL(station *Station, relUrl string) *TimeURL {
	m := urlDayRegExp.FindStringSubmatch(relUrl)
	if nil == m {
		return nil
	}
	dayStr := m[1]

	day, err := time.ParseInLocation("2006-01-02 15:04", dayStr+" "+station.CloseDown, localLoc)
	if nil != err {
		panic(err)
	}

	programURL := *(station.ProgramURL)
	programURL.Path = relUrl
	return &TimeURL{Time: day, Source: programURL}
}

func ParseDayURLsNode(station *Station, root *html.Node, c chan<- TimeURL) {
	i := 0
	for _, a := range scrape.FindAll(root, func(n *html.Node) bool { return atom.A == n.DataAtom && atom.Td == n.Parent.DataAtom }) {
		rel := scrape.Attr(a, "href")
		d := newTimeURL(station, rel)
		if nil == d {
			continue
		}
		// use only every 3rd day schedule url because each one contains 3 days
		i += 1
		if 2 != i%3 {
			continue
		}
		// fmt.Printf("ok %s\n", d.String())
		c <- (*d)
	}
}

func ParseDayURLsReader(station *Station, read io.Reader, c chan<- TimeURL) {
	root, err := html.Parse(read)
	if nil != err {
		panic(err)
	}
	ParseDayURLsNode(station, root, c)
}

func ParseDayURLs(station *Station, c chan<- TimeURL) {
	resp, err := http.Get(station.ProgramURL.String())
	if nil != err {
		panic(err)
	}
	ParseDayURLsReader(station, resp.Body, c)
}

/////////////////////////////////////////////////////////////////////////////
/// Find broadcast schedule per (three) day
/////////////////////////////////////////////////////////////////////////////

func mustParseInt(s string) int {
	ret, err := strconv.ParseInt(s, 10, 12)
	if nil != err {
		panic(err)
	}
	return int(ret)
}

func yearForMonth(mo time.Month, now *time.Time) int {
	year := now.Year()
	if mo+6 <= now.Month() {
		year += 1
	}
	return year
}

var (
	dayMonthRegExp        = regexp.MustCompile(",[ \n]+([0-9]{2})[.]([0-9]{2})[.]")
	hourMinuteTitleRegExp = regexp.MustCompile("([0-9]{2}):([0-9]{2})[ \n]+(.+)")
)

func timeForH4(h4 string, now *time.Time) (year int, mon time.Month, day int, err error) {
	m := dayMonthRegExp.FindStringSubmatch(h4)
	if nil == m {
		// err = error.New("Couldn't parse " + h4)
		return
	}
	mon = time.Month(mustParseInt(m[2]))
	year = yearForMonth(mon, now)
	day = mustParseInt(m[1])
	return
}

func ParseBroadcastURLsNode(d TimeURL, root *html.Node, c chan<- BroadcastURL) {
	const closeDownHour int = 5
	now := time.Now()
	for _, h4 := range scrape.FindAll(root, func(n *html.Node) bool { return atom.H4 == n.DataAtom }) {
		year, month, day, err := timeForH4(scrape.Text(h4), &now)
		if nil != err {
			panic(err)
		}
		// fmt.Printf("%d-%d-%d %s\n", year, month, day, err)
		for _, a := range scrape.FindAll(h4.Parent, func(n *html.Node) bool { return atom.A == n.DataAtom && atom.Dt == n.Parent.DataAtom }) {
			m := hourMinuteTitleRegExp.FindStringSubmatch(scrape.Text(a))
			if nil == m {
				panic(errors.New("Couldn't parse <a>"))
			}
			var ur url.URL = d.Source
			ur.Path = scrape.Attr(a, "href")

			hour := mustParseInt(m[1])
			var day_ int = day
			if hour < closeDownHour {
				day_ += 1
			}
			b := BroadcastURL{
				TimeURL: TimeURL{
					Time:   time.Date(year, month, day_, hour, mustParseInt(m[2]), 0, 0, localLoc),
					Source: ur,
				},
				Title: m[3],
			}
			// fmt.Printf("%s %s\n", b.TimeURL.String(), b.Title)
			c <- b
		}
	}
}

func ParseBroadcastURLsReader(d TimeURL, read io.Reader, c chan<- BroadcastURL) {
	root, err := html.Parse(read)
	if nil != err {
		panic(err)
	}
	ParseBroadcastURLsNode(d, root, c)
}

func ParseBroadcastURLs(d TimeURL, c chan<- BroadcastURL) {
	resp, err := http.Get(d.Source.String())
	if nil != err {
		panic(err)
	}
	ParseBroadcastURLsReader(d, resp.Body, c)
}

/////////////////////////////////////////////////////////////////////////////
/// Parse broadcast
/////////////////////////////////////////////////////////////////////////////

// Completely re-scrape everything and verify consistence at least of Time, evtl. Title
func ParseBroadcastNode(d BroadcastURL, root *html.Node) Broadcast {
	panic("Not implemented yet.")
}

func ParseBroadcastReader(d BroadcastURL, read io.Reader) Broadcast {
	root, err := html.Parse(read)
	if nil != err {
		panic(err)
	}
	return ParseBroadcastNode(d, root)
}

func ParseBroadcast(d BroadcastURL) Broadcast {
	resp, err := http.Get(d.Source.String())
	if nil != err {
		panic(err)
	}
	return ParseBroadcastReader(d, resp.Body)
}
