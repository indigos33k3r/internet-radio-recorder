// Copyright (c) 2015-2016 Marcus Rohrmoser, http://purl.mro.name/recorder
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

package m945 // import "purl.mro.name/recorder/radio/scrape/m945"

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	r "purl.mro.name/recorder/radio/scrape"
)

/////////////////////////////////////////////////////////////////////////////
/// Just wrap Station into a distinct, local type - a Scraper, naturally
type station struct {
	r.Station
}

// Station Factory
func Station(identifier string) *station {
	tz, err := time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
	s := map[string]*station{
		"m945": &station{Station: r.Station{Name: "M 94.5", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.m945.de/programm/"), Identifier: identifier, TimeZone: tz}},
	}[identifier]
	return s
}

///////////////////////////////////////////////////////////////////////
/// r.Scraper

func (s *station) Matches(now *time.Time) (ok bool) {
	return true
}

// Synthesise the day urls for incremental scraping.
func (s *station) Scrape(jobs chan<- r.Scraper, results chan<- r.Broadcaster) (err error) {
	t0 := time.Now()
	for _, now := range r.IncrementalNows(&t0) {
		day, _ := s.dayURLForDate(now)
		jobs <- day
	}
	return
}

///////////////////////////////////////////////////////////////////////
// http://www.m945.de/programm/?daterequest=2015-11-14

func (s *station) dayURLForDate(day time.Time) (ret *dayUrl, err error) {
	ret = &dayUrl{
		TimeURL: r.TimeURL{
			Time:    time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, s.TimeZone),
			Source:  *r.MustParseURL(s.ProgramURL.String() + day.Format("?daterequest=2006-01-02")),
			Station: s.Station,
		},
	}
	// err = errors.New("Not ümplemented yet.")
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type - a Scraper, naturally
type dayUrl struct {
	r.TimeURL
}

/// r.Scraper
func (day dayUrl) Matches(now *time.Time) (ok bool) {
	return true
}

// Scrape broadcasts from a day page.
func (day dayUrl) Scrape(jobs chan<- r.Scraper, results chan<- r.Broadcaster) (err error) {
	bcs, err := day.parseBroadcastsFromURL()
	if nil == err {
		for _, bc := range bcs {
			results <- bc
		}
	}
	return
}

var (
	lang_de   string = "de"
	publisher string = "http://www.m945.de/"
)

func (day *dayUrl) parseBroadcastsFromNode(root *html.Node) (ret []*r.Broadcast, err error) {
	nodes := scrape.FindAll(root, func(n *html.Node) bool { return atom.Div == n.DataAtom && "time" == scrape.Attr(n, "class") })
	ret = make([]*r.Broadcast, len(nodes))
	for index, tim := range nodes {
		// prepare response
		bc := r.Broadcast{
			BroadcastURL: r.BroadcastURL{
				TimeURL: day.TimeURL,
			},
		}
		// some defaults
		bc.Language = &lang_de
		bc.Publisher = &publisher
		// set start time
		{
			div_t := strings.TrimSpace(scrape.Text(tim))
			if 5 != len(div_t) {
				continue
			}
			hour := r.MustParseInt(div_t[0:2])
			minute := r.MustParseInt(div_t[3:5])
			bc.Time = time.Date(day.Year(), day.Month(), day.Day(), hour, minute, 0, 0, day.TimeZone)
			if index > 0 {
				ret[index-1].DtEnd = &bc.Time
			}
		}
		for _, tit := range scrape.FindAll(tim.Parent, func(n *html.Node) bool {
			return atom.A == n.DataAtom && atom.Div == n.Parent.DataAtom && "descr" == scrape.Attr(n.Parent, "class")
		}) {
			// Title
			bc.Title = strings.TrimSpace(scrape.Text(tit))
			href := scrape.Attr(tit, "href")
			if "" != href {
				u, _ := url.Parse(href)
				bc.Subject = day.Source.ResolveReference(u)
			}

			desc_node := tit.Parent
			desc_node.RemoveChild(tit)
			{
				// Description
				var desc string = r.TextWithBr(desc_node)
				re := regexp.MustCompile("[ ]*(\\s)[ ]*") // collapse whitespace, keep \n
				t := desc                                 // mark paragraphs with a double \n
				t = re.ReplaceAllString(t, "$1")          // collapse whitespace (not the \n\n however)
				t = strings.TrimSpace(t)
				bc.Description = &t
			}
			// fmt.Fprintf(os.Stderr, "\n")
		}
		ret[index] = &bc
	}
	// fmt.Fprintf(os.Stderr, "len(ret) = %d '%s'\n", len(ret), day.Source.String())
	if len(nodes) > 0 {
		midnight := time.Date(day.Year(), day.Month(), day.Day(), 24, 0, 0, 0, day.TimeZone)
		ret[len(nodes)-1].DtEnd = &midnight
	}
	return
}

func (day *dayUrl) parseBroadcastsFromReader(read io.Reader) (ret []*r.Broadcast, err error) {
	cr := r.NewCountingReader(read)
	root, err := html.Parse(cr)
	fmt.Fprintf(os.Stderr, "parsed %d bytes\n", cr.TotalBytes)
	if nil != err {
		return
	}
	return day.parseBroadcastsFromNode(root)
}

func (day *dayUrl) parseBroadcastsFromURL() (ret []*r.Broadcast, err error) {
	resp, err := http.Get(day.Source.String())
	if nil != err {
		return
	}
	defer resp.Body.Close()
	return day.parseBroadcastsFromReader(resp.Body)
}
