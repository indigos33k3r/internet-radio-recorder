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
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	r "purl.mro.name/recorder/radio/scrape"
)

var _ = os.Stderr

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
		"dlf": &station{Station: r.Station{Name: "Deutschlandfunk", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.deutschlandfunk.de/programmvorschau.281.de.html"), Identifier: identifier, TimeZone: tz}},
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
			Source:  *r.MustParseURL(s.ProgramURL.String() + day.Format("?drbm:date=02.01.2006")),
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
	publisher string = "http://www.deutschlandfunk.de/"
)

func (day *dayUrl) parseBroadcastsFromNode(root *html.Node) (ret []*r.Broadcast, err error) {
	// fmt.Fprintf(os.Stderr, "%s\n", day.Source.String())
	index := 0
	for _, at := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.A == n.DataAtom && atom.Td == n.Parent.DataAtom && atom.Tr == n.Parent.Parent.DataAtom && "time" == scrape.Attr(n.Parent, "class")
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
		// set start time
		{
			a_id := scrape.Attr(at, "id")
			if "" == a_id {
				continue
			}
			// fmt.Fprintf(os.Stderr, "  a_id=%s\n", a_id)
			bc.Source.Fragment = a_id
			hour := r.MustParseInt(a_id[0:2])
			minute := r.MustParseInt(a_id[2:4])
			if 24 < hour || 60 < minute {
				continue
			}
			bc.Time = time.Date(day.Year(), day.Month(), day.Day(), hour, minute, 0, 0, day.TimeZone)
			if index > 0 {
				ret[index-1].DtEnd = &bc.Time
			}
		}
		// Title
		for idx, h3 := range scrape.FindAll(at.Parent.Parent, func(n *html.Node) bool {
			return atom.H3 == n.DataAtom && atom.Td == n.Parent.DataAtom && atom.Tr == n.Parent.Parent.DataAtom && "description" == scrape.Attr(n.Parent, "class")
		}) {
			if idx != 0 {
				err = errors.New("There was more than 1 <tr><td class='description'><h3>")
				return
			}
			for idx, h3_a := range scrape.FindAll(h3, func(n *html.Node) bool {
				return atom.A == n.DataAtom && "" == scrape.Attr(n, "class")
			}) {
				if idx != 0 {
					err = errors.New("There was more than 1 <tr><td class='description'><h3><a>")
					return
				}
				bc.Title = scrape.Text(h3_a)
				// bc.Source = scrape.Attr(h3_a, "href") // make URL absolute
			}
			bc.Title = strings.TrimSpace(bc.Title)
			if "" == bc.Title {
				bc.Title = r.TextChildrenNoClimb(h3)
			}
			// fmt.Fprintf(os.Stderr, " '%s'", bc.Title)
			{
				// Description
				var desc []string = r.TextsWithBr(scrape.FindAll(h3.Parent, func(n *html.Node) bool { return atom.P == n.DataAtom }))
				re := regexp.MustCompile("[ ]*(\\s)") // collapse whitespace, keep \n
				t := strings.Join(desc, "\n\n")       // mark paragraphs with a double \n
				t = re.ReplaceAllString(t, "$1")      // collapse whitespace (not the \n\n however)
				t = strings.TrimSpace(t)
				bc.Description = &t
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
	resp, err := http.Get(day.Source.String())
	if nil != err {
		return
	}
	defer resp.Body.Close()
	return day.parseBroadcastsFromReader(resp.Body)
}
