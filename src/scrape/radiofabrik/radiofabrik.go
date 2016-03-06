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

package radiofabrik // import "purl.mro.name/recorder/radio/scrape/radiofabrik"

import (
	"errors"
	"fmt"
	"io"
	"net/http"
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
		"radiofabrik": &station{Station: r.Station{Name: "radiofabrik", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.radiofabrik.at/programm0/tagesprogramm.html"), Identifier: identifier, TimeZone: tz}},
	}[identifier]
	return s
}

/// Stringer
func (s *station) String() string {
	return fmt.Sprintf("Station '%s'", s.Name)
}

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
// http://www.deutschlandfunk.de/programmvorschau.281.de.html?drbm:date=19.11.2015

func (s *station) dayURLForDate(day time.Time) (ret *dayUrl, err error) {
	ret = &dayUrl{
		TimeURL: r.TimeURL{
			Time:    time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, s.TimeZone),
			Source:  *r.MustParseURL(s.ProgramURL.String() + day.Format("?foo=bar&si_day=02&si_month=01&si_year=2006")),
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
	publisher string = "http://www.radiofabrik.at/"
)

func (day *dayUrl) parseBroadcastsFromNode(root *html.Node) (ret []*r.Broadcast, err error) {
	// fmt.Fprintf(os.Stderr, "%s\n", day.Source.String())
	index := 0
	for _, at := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.Div == n.DataAtom && "si_dayList_starttime" == scrape.Attr(n, "class")
	}) {
		// prepare response
		bc := r.Broadcast{
			BroadcastURL: r.BroadcastURL{
				TimeURL: day.TimeURL,
			},
		}
		// some defaults
		bc.Language = &lang_de
		bc.Publisher = &publisher
		empty_str := ""
		bc.Description = &empty_str
		// set start time
		{
			hhmm := scrape.Text(at)
			// fmt.Fprintf(os.Stderr, "  a_id=%s\n", a_id)
			hour := r.MustParseInt(hhmm[0:2])
			minute := r.MustParseInt(hhmm[3:5])
			if 24 < hour || 60 < minute {
				continue
			}
			bc.Time = time.Date(day.Year(), day.Month(), day.Day(), hour, minute, 0, 0, day.TimeZone)
			if index > 0 {
				ret[index-1].DtEnd = &bc.Time
			}
		}
		// Title
		for idx, div := range scrape.FindAll(at.Parent, func(n *html.Node) bool {
			return atom.Div == n.DataAtom && "si_dayList_description" == scrape.Attr(n, "class")
		}) {
			if idx != 0 {
				err = errors.New("There was more than 1 <div class='si_dayList_description'>")
				return
			}
			bc.Title = scrape.Text(div)
			//				u, _ := url.Parse(scrape.Attr(h3_a, "href"))
			//			bc.Subject = day.Source.ResolveReference(u)

			bc.Title = strings.TrimSpace(bc.Title)
			for idx1, a := range scrape.FindAll(div, func(n *html.Node) bool {
				return atom.A == n.DataAtom
			}) {
				if idx1 != 0 {
					err = errors.New("There was more than 1 <a>")
					return
				}
				u, _ := url.Parse(scrape.Attr(a, "href"))
				bc.Subject = day.Source.ResolveReference(u)
			}
		}
		// fmt.Fprintf(os.Stderr, "\n")
		ret = append(ret, &bc)
		index += 1
	}
	// fmt.Fprintf(os.Stderr, "len(ret) = %d '%s'\n", len(ret), day.Source.String())
	if index > 0 {
		midnight := time.Date(day.Year(), day.Month(), day.Day(), 24, 0, 0, 0, day.TimeZone)
		ret[index-1].DtEnd = &midnight
	}
	return
}

func (day *dayUrl) parseBroadcastsFromReader(read io.Reader) (ret []*r.Broadcast, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return day.parseBroadcastsFromNode(root)
}

func (day *dayUrl) parseBroadcastsFromURL() (ret []*r.Broadcast, err error) {
	s := day.Source.String()
	m, err := url.ParseQuery(s)
	if nil != err {
		return
	}
	resp, err := http.PostForm(s, m)
	if nil != err {
		return
	}
	defer resp.Body.Close()
	return day.parseBroadcastsFromReader(resp.Body)
}
