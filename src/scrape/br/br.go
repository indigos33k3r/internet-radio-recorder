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

package br // import "purl.mro.name/recorder/radio/scrape/br"

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
	rscrape "purl.mro.name/recorder/radio/scrape"
)

var _ = fmt.Printf

/////////////////////////////////////////////////////////////////////////////
///

func urlMustParse(s string) *url.URL {
	ret, err := url.Parse(s)
	if nil != err {
		panic(err)
	}
	return ret
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap Station into a distinct, local type.
type StationBR struct {
	rscrape.Station
}

// Station Factory
func Station(identifier string) *StationBR {
	tz, err := time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
	s := map[string]StationBR{
		"b+":       StationBR{Station: rscrape.Station{Name: "Bayern Plus", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern-plus/programmkalender/bayern-plus114.html"), Identifier: identifier, TimeZone: tz}},
		"b1":       StationBR{Station: rscrape.Station{Name: "Bayern 1", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern1/service/programm/index.html"), Identifier: identifier, TimeZone: tz}},
		"b2":       StationBR{Station: rscrape.Station{Name: "Bayern 2", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern2/service/programm/index.html"), Identifier: identifier, TimeZone: tz}},
		"b3":       StationBR{Station: rscrape.Station{Name: "Bayern 3", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern3/programmkalender/br-drei100.html"), Identifier: identifier, TimeZone: tz}},
		"b4":       StationBR{Station: rscrape.Station{Name: "Bayern 4", CloseDown: "06:00", ProgramURL: urlMustParse("http://www.br.de/radio/br-klassik/programmkalender/br-klassik120.html"), Identifier: identifier, TimeZone: tz}},
		"b5":       StationBR{Station: rscrape.Station{Name: "Bayern 5", CloseDown: "06:00", ProgramURL: urlMustParse("http://www.br.de/radio/b5-aktuell/programmkalender/b5aktuell116.html"), Identifier: identifier, TimeZone: tz}},
		"brheimat": StationBR{Station: rscrape.Station{Name: "BR Heimat 5", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/br-heimat/programmkalender/br-heimat-116.html"), Identifier: identifier, TimeZone: tz}},
		"puls":     StationBR{Station: rscrape.Station{Name: "Puls", CloseDown: "07:00", ProgramURL: urlMustParse("http://www.br.de/puls/programm/puls-radio/programmkalender/programmfahne104.html"), Identifier: identifier, TimeZone: tz}},
	}[identifier]
	return &s
}

func (s *StationBR) String() string {
	return fmt.Sprintf("Station '%s'", s.Station.Name)
}

func (s *StationBR) ParseDayURLsNode(root *html.Node) (ret []*TimeURLBR, err error) {
	i := 0
	ret = []*TimeURLBR{}
	for _, a := range scrape.FindAll(root, func(n *html.Node) bool { return atom.A == n.DataAtom && atom.Td == n.Parent.DataAtom }) {
		rel := scrape.Attr(a, "href")
		d, err := s.newTimeURL(rel)
		if nil != err {
			continue
		}
		// use only every 3rd day schedule url because each one contains 3 days
		i += 1
		if 2 != i%3 {
			continue
		}
		// fmt.Printf("ok %s\n", d.String())
		ret = append(ret, &TimeURLBR{TimeURL: d})
	}
	return
}

func (s *StationBR) ParseDayURLsReader(read io.Reader) (ret []*TimeURLBR, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.ParseDayURLsNode(root)
}

func (s *StationBR) ParseDayURLs() (ret []*TimeURLBR, err error) {
	resp, err := http.Get(s.ProgramURL.String())
	if nil != err {
		return
	}
	return s.ParseDayURLsReader(resp.Body)
}

// Scrape slice of TimeURLBR - all calendar (day) entries of the station program url
func (s *StationBR) Scrape(results chan<- rscrape.Broadcaster, jobs chan<- rscrape.Scraper, now *time.Time) (err error) {
	time_urls, err := s.ParseDayURLs()
	if nil == err {
		for _, t := range time_urls {
			jobs <- t
		}
	}
	return
}

func (s *StationBR) Matches(now *time.Time) (ok bool) {
	return true
}

var (
	urlDayRegExp *regexp.Regexp = regexp.MustCompile("^/radio/.+~_date-(\\d{4}-\\d{2}-\\d{2})_-.+$")
)

func (s *StationBR) newTimeURL(relUrl string) (ret rscrape.TimeURL, err error) {
	m := urlDayRegExp.FindStringSubmatch(relUrl)
	if nil == m {
		err = errors.New("Couldn't match regexp on " + relUrl + "")
		return
	}
	dayStr := m[1]

	day, err := time.ParseInLocation("2006-01-02 15:04", dayStr+" "+s.Station.CloseDown, s.Station.TimeZone)
	if nil != err {
		return
	}

	programURL := *(s.ProgramURL)
	programURL.Path = relUrl
	ret = rscrape.TimeURL{Time: day, Source: programURL}
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type.
type TimeURLBR struct {
	rscrape.TimeURL
	Station *StationBR
}

// Scrape slice of BroadcastURLBR - all per-day broadcast entries of the day url
func (day *TimeURLBR) Scrape(results chan<- rscrape.Broadcaster, jobs chan<- rscrape.Scraper, now *time.Time) (err error) {
	broadcast_urls, err := day.Station.ParseBroadcastURLs(&day.Source)
	if nil == err {
		for _, b := range broadcast_urls {
			// fmt.Printf("____ ___ %s\n", b)
			jobs <- b
		}
	}
	return
}

func (s *TimeURLBR) Matches(now *time.Time) (ok bool) {
	start := &s.Time
	if nil == now || nil == start {
		return false
	}
	for _, n := range []time.Time{now.Add(1 * time.Second), now.Add(24 * time.Hour), now.Add(4 * 7 * 24 * time.Hour)} {
		dt := start.Sub(n)
		if -24*time.Hour <= dt && dt <= 24*time.Hour {
			return true
		}
	}
	return false
}

func (s *StationBR) ParseBroadcastURLsNode(day_url *url.URL, root *html.Node) (ret []*BroadcastURLBR, err error) {
	ret = []*BroadcastURLBR{}
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
			ur := *day_url
			ur.Path = scrape.Attr(a, "href")

			hour := mustParseInt(m[1])
			var day_ int = day
			if hour < closeDownHour {
				day_ += 1
			}
			// fmt.Printf("%s %s\n", b.rscrape.TimeURL.String(), b.Title)
			ret = append(ret, &BroadcastURLBR{BroadcastURL: rscrape.BroadcastURL{
				TimeURL: rscrape.TimeURL{
					Time:   time.Date(year, month, day_, hour, mustParseInt(m[2]), 0, 0, localLoc),
					Source: ur,
				},
				Title: strings.TrimSpace(m[3]),
			},
				Station: s})
		}
	}
	return
}

func (s *StationBR) ParseBroadcastURLsReader(day_url *url.URL, read io.Reader) (ret []*BroadcastURLBR, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.ParseBroadcastURLsNode(day_url, root)
}

func (s *StationBR) ParseBroadcastURLs(day_url *url.URL) (ret []*BroadcastURLBR, err error) {
	resp, err := http.Get(day_url.String())
	if nil != err {
		return
	}
	return s.ParseBroadcastURLsReader(day_url, resp.Body)
}

/////////////////////////////////////////////////////////////////////////////
///

type BroadcastURLBR struct {
	rscrape.BroadcastURL
	Station *StationBR
}

func (b *BroadcastURLBR) Scrape(results chan<- rscrape.Broadcaster, jobs chan<- rscrape.Scraper, now *time.Time) (err error) {
	bc, err := b.Station.ParseBroadcast(&b.TimeURL.Source)
	if nil == err {
		results <- bc
	}
	return
}

func (s *BroadcastURLBR) Matches(now *time.Time) (ok bool) {
	start := &s.Time
	if nil == now || nil == start {
		return false
	}
	for _, n := range []time.Time{now.Add(1 * time.Second), now.Add(24 * time.Hour), now.Add(4 * 7 * 24 * time.Hour)} {
		dt := start.Sub(n)
		if 0 <= dt && dt <= 60*time.Minute {
			return true
		}
	}
	return false
}

/////////////////////////////////////////////////////////////////////////////
///

var (
	localLoc *time.Location // TODO: abolish, replace with rscrape.Station.TimeZone
)

func init() {
	var err error
	localLoc, err = time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
}

/////////////////////////////////////////////////////////////////////////////
/// Find daily URLs
/////////////////////////////////////////////////////////////////////////////

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
	dayMonthRegExp        = regexp.MustCompile(",\\s+(\\d{2})\\.(\\d{2})\\.")
	hourMinuteTitleRegExp = regexp.MustCompile("(\\d{2}):(\\d{2})\\s+(\\S(?:.*\\S)?)")
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

/////////////////////////////////////////////////////////////////////////////
/// Parse broadcast
/////////////////////////////////////////////////////////////////////////////

func textChildrenNoClimb(node *html.Node) string {
	ret := []string{}
	for n := node.FirstChild; nil != n; n = n.NextSibling {
		if html.TextNode != n.Type {
			continue
		}
		ret = append(ret, strings.TrimSpace(n.Data))
	}
	return strings.Join(ret, "")
}

var (
	bcDateRegExp = regexp.MustCompile(",\\s+(\\d{2})\\.(\\d{2})\\.(\\d{4})\\s+(\\d{2}):(\\d{2})\\s+bis\\s+(\\d{2}):(\\d{2})")
)

// Completely re-scrape everything and verify consistence at least of Time, evtl. Title
func (s *StationBR) ParseBroadcastNode(url *url.URL, root *html.Node) (bc rscrape.Broadcast, err error) {
	bc.BroadcastURL.TimeURL.Source = *url

	// Title, TitleSeries, TitleEpisode
	for i, h1 := range scrape.FindAll(root, func(n *html.Node) bool { return atom.H1 == n.DataAtom && "bcast_headline" == scrape.Attr(n, "class") }) {
		if i != 0 {
			err = errors.New("There was more than 1 <h1 class='bcast_headline'>")
			return
		}
		bc.Title = textChildrenNoClimb(h1)
		for _, span := range scrape.FindAll(h1, func(n *html.Node) bool { return atom.Span == n.DataAtom }) {
			switch scrape.Attr(span, "class") {
			case "bcast_overline":
				s := textChildrenNoClimb(span)
				bc.TitleSeries = &s
			case "bcast_subtitle":
				s := textChildrenNoClimb(span)
				bc.TitleEpisode = &s
			default:
				err = errors.New("unexpected <span> inside <h1>")
				return
			}
			bc.Title = textChildrenNoClimb(h1)
		}
	}

	// BroadcastURL.TimeURL.Time, DtEnd
	for idx, p := range scrape.FindAll(root, func(n *html.Node) bool { return atom.P == n.DataAtom && "bcast_date" == scrape.Attr(n, "class") }) {
		if idx != 0 {
			err = errors.New("There was more than 1 <p class='bcast_date'>")
			return
		}
		m := bcDateRegExp.FindStringSubmatch(scrape.Text(p))
		if nil == m {
			err = errors.New("There was no date match")
			return
		}
		i := mustParseInt
		bc.BroadcastURL.TimeURL.Time = time.Date(i(m[3]), time.Month(i(m[2])), i(m[1]), i(m[4]), i(m[5]), 0, 0, localLoc)
		t := time.Date(i(m[3]), time.Month(i(m[2])), i(m[1]), i(m[6]), i(m[7]), 0, 0, localLoc)
		bc.DtEnd = &t
	}

	// Subject
	for _, a := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.A == n.DataAtom && strings.HasPrefix(scrape.Attr(n, "class"), "link_broadcast media_broadcastSeries")
	}) {
		u := bc.BroadcastURL.TimeURL.Source
		u.Path = scrape.Attr(a, "href")
		bc.Subject = &u
	}

	// Modified
	for _, meta := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.Meta == n.DataAtom && "og:article:modified_time" == scrape.Attr(n, "property")
	}) {
		v, _ := time.Parse(time.RFC3339, scrape.Attr(meta, "content"))
		bc.Modified = &v
	}

	// Author
	for _, meta := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.Meta == n.DataAtom && "author" == scrape.Attr(n, "name")
	}) {
		s := scrape.Attr(meta, "content")
		bc.Author = &s
	}

	// Image
	// Description
	return
}

func (s *StationBR) ParseBroadcastReader(url *url.URL, read io.Reader) (bc rscrape.Broadcast, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.ParseBroadcastNode(url, root)
}

func (s *StationBR) ParseBroadcast(url *url.URL) (bc rscrape.Broadcast, err error) {
	resp, err := http.Get(url.String())
	if nil != err {
		return
	}
	return s.ParseBroadcastReader(url, resp.Body)
}
