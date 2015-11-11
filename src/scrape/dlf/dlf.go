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

package dlf // import "purl.mro.name/recorder/radio/scrape/dlf"

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	r "purl.mro.name/recorder/radio/scrape"
)

var _ = errors.New
var _ = fmt.Printf
var _ = io.Copy
var _ = http.Get
var _ = url.Parse
var _ = regexp.MustCompile
var _ = strconv.AppendInt
var _ = strings.Count
var _ = time.Sleep
var _ = scrape.Text
var _ = html.Render
var _ = atom.Br

/////////////////////////////////////////////////////////////////////////////
/// Just wrap Station into a distinct, local type.
type StationDLF struct {
	r.Station
}

// Station Factory
func Station(identifier string) *StationDLF {
	tz, err := time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
	s := map[string]*StationDLF{
		"dlf": &StationDLF{Station: r.Station{Name: "Deutschlandfunk", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.deutschlandfunk.de/programmvorschau.281.de.html"), Identifier: identifier, TimeZone: tz}},
	}[identifier]
	return s
}

/// Stringer
func (s *StationDLF) String() string {
	return fmt.Sprintf("Station '%s'", s.Name)
}

/// r.Scraper
func (s *StationDLF) Matches(now *time.Time) (ok bool) {
	return true
}

// Scrape slice of DayURLDLF - all calendar (day) entries of the station program url
func (s *StationDLF) Scrape(jobs chan<- r.Scraper, results chan<- r.Broadcaster) (err error) {
	time_urls, err := s.parseDayURLs()
	if nil == err {
		for _, t := range time_urls {
			jobs <- t
		}
	}
	return
}

func (s *StationDLF) parseDayURLsNode(root *html.Node) (ret []*DayURLDLF, err error) {
	i := 0
	ret = []*DayURLDLF{}
	for _, a := range scrape.FindAll(root, func(n *html.Node) bool { return atom.A == n.DataAtom && atom.Td == n.Parent.DataAtom }) {
		rel := scrape.Attr(a, "href")
		fmt.Printf("%s", rel)
		d := DayURLDLF{TimeURL: r.TimeURL{Time: time.Time{}}}
		// fmt.Printf("ok %s\n", d.String())
		ret = append(ret, &d)
	}
	fmt.Printf("%d", i)
	return
}

func (s *StationDLF) parseDayURLsReader(read io.Reader) (ret []*DayURLDLF, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.parseDayURLsNode(root)
}

func (s *StationDLF) parseDayURLs() (ret []*DayURLDLF, err error) {
	resp, err := http.Get(s.ProgramURL.String())
	defer resp.Body.Close()
	if nil != err {
		return
	}
	return s.parseDayURLsReader(resp.Body)
}

///////////////////////////////////////////////////////////////////////
// http://www.deutschlandfunk.de/programmvorschau.281.de.html?drbm:date=19.11.2015

func (s *StationDLF) dayURLForDate(day time.Time) (ret *DayURLDLF, err error) {
	ret = &DayURLDLF{
		TimeURL: r.TimeURL{
			Time:   time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, s.TimeZone),
			Source: *r.MustParseURL(s.ProgramURL.String() + day.Format("?drbm:date=02.01.2006")),
		},
		Station: s.Station,
	}
	// err = errors.New("Not ümplemented yet.")
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type.
type DayURLDLF struct {
	r.TimeURL
	r.Station
}

/// r.Scraper
func (s *DayURLDLF) Matches(now *time.Time) (ok bool) {
	return true
}

// Scrape slice of DayURLDLF - all calendar (day) entries of the station program url
func (s *DayURLDLF) Scrape(jobs chan<- r.Scraper, results chan<- r.Broadcaster) (err error) {
	bcs, err := s.parseBroadcastsFromURL()
	if nil == err {
		for _, bc := range bcs {
			results <- bc
		}
	}
	return
}

func (s *DayURLDLF) parseBroadcastsFromNode(root *html.Node) (ret []*r.Broadcast, err error) {
	i := 0
	fmt.Printf("%d", i)
	ret = []*r.Broadcast{}
	for _, a := range scrape.FindAll(root, func(n *html.Node) bool { return atom.A == n.DataAtom && atom.Td == n.Parent.DataAtom }) {
		rel := scrape.Attr(a, "href")
		fmt.Printf("%s", rel)
	}
	return
}

func (s *DayURLDLF) parseBroadcastsFromReader(read io.Reader) (ret []*r.Broadcast, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.parseBroadcastsFromNode(root)
}

func (day *DayURLDLF) parseBroadcastsFromURL() (ret []*r.Broadcast, err error) {
	resp, err := http.Get(day.Source.String())
	defer resp.Body.Close()
	if nil != err {
		return
	}
	return day.parseBroadcastsFromReader(resp.Body)
}
