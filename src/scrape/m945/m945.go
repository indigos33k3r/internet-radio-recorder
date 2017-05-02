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
	"io"
	"net/url"
	"strings"
	"time"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	r "purl.mro.name/recorder/radio/scrape"
)

/////////////////////////////////////////////////////////////////////////////
/// Just wrap Station into a distinct, local type - a Scraper, naturally
type station r.Station

// Station Factory
func Station(identifier string) *station {
	tz, _ := time.LoadLocation("Europe/Berlin")
	switch identifier {
	case
		"m945":
		s := station(r.Station{Name: "M 94.5", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.m945.de/programm/"), Identifier: identifier, TimeZone: tz})
		return &s
	}
	return nil
}

///////////////////////////////////////////////////////////////////////
/// r.Scraper

func (s *station) Matches(nows []time.Time) (ok bool) {
	return true
}

// Synthesise calItemRangeURLs for incremental scraping and queue them up
func (s *station) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	now := time.Now()
	for _, t0 := range r.IncrementalNows(now) {
		day, _ := s.dayURLForDate(t0)
		jobs = append(jobs, r.Scraper(*day))
	}
	return
}

///////////////////////////////////////////////////////////////////////
// http://www.m945.de/programm/?daterequest=2015-11-14

func (s *station) dayURLForDate(day time.Time) (ret *timeURL, err error) {
	r := timeURL(r.TimeURL{
		Time:    time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL(s.ProgramURL.String() + day.Format("?daterequest=2006-01-02")),
		Station: r.Station(*s),
	})
	ret = &r
	// err = errors.New("Not ümplemented yet.")
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type - a Scraper, naturally
type timeURL r.TimeURL

/// r.Scraper
func (day timeURL) Matches(nows []time.Time) (ok bool) {
	return true
}

// Scrape broadcasts from a day page.
func (day timeURL) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	bcs, err := day.parseBroadcastsFromURL()
	if nil == err {
		for _, bc := range bcs {
			results = append(results, bc)
		}
	}
	return
}

var (
	langDe   string = "de"
	publisher string = "http://www.m945.de/"
)

func (day *timeURL) parseBroadcastsFromNode(root *html.Node) (ret []*r.Broadcast, err error) {
	nodes := scrape.FindAll(root, func(n *html.Node) bool { return atom.Div == n.DataAtom && "time" == scrape.Attr(n, "class") })
	ret = make([]*r.Broadcast, len(nodes))
	for index, tim := range nodes {
		// prepare response
		bc := r.Broadcast{
			BroadcastURL: r.BroadcastURL{
				TimeURL: r.TimeURL(*day),
			},
		}
		// some defaults
		bc.Language = &langDe
		bc.Publisher = &publisher
		// set start time
		{
			divT := strings.TrimSpace(scrape.Text(tim))
			if 5 != len(divT) {
				continue
			}
			hour := r.MustParseInt(divT[0:2])
			minute := r.MustParseInt(divT[3:5])
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

			descNode := tit.Parent
			descNode.RemoveChild(tit)
			description := r.TextWithBrFromNodeSet([]*html.Node{descNode})
			bc.Description = &description
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

func (day *timeURL) parseBroadcastsFromReader(read io.Reader, cr0 *r.CountingReader) (ret []*r.Broadcast, err error) {
	cr := r.NewCountingReader(read)
	root, err := html.Parse(cr)
	r.ReportLoad("🐦", cr0, cr, day.Source)
	if nil != err {
		return
	}
	return day.parseBroadcastsFromNode(root)
}

func (day *timeURL) parseBroadcastsFromURL() (ret []*r.Broadcast, err error) {
	bo, cr, err := r.HttpGetBody(day.Source)
	if nil == bo {
		return nil, err
	}
	return day.parseBroadcastsFromReader(bo, cr)
}
