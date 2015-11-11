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
	r "purl.mro.name/recorder/radio/scrape"
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
	r.Station
}

// Station Factory
func Station(identifier string) *StationBR {
	tz, err := time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
	s := map[string]StationBR{
		"b+":       StationBR{Station: r.Station{Name: "Bayern Plus", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern-plus/programmkalender/bayern-plus114.html"), Identifier: identifier, TimeZone: tz}},
		"b1":       StationBR{Station: r.Station{Name: "Bayern 1", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern1/service/programm/index.html"), Identifier: identifier, TimeZone: tz}},
		"b2":       StationBR{Station: r.Station{Name: "Bayern 2", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern2/service/programm/index.html"), Identifier: identifier, TimeZone: tz}},
		"b3":       StationBR{Station: r.Station{Name: "Bayern 3", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern3/programmkalender/br-drei100.html"), Identifier: identifier, TimeZone: tz}},
		"b4":       StationBR{Station: r.Station{Name: "Bayern 4", CloseDown: "06:00", ProgramURL: urlMustParse("http://www.br.de/radio/br-klassik/programmkalender/br-klassik120.html"), Identifier: identifier, TimeZone: tz}},
		"b5":       StationBR{Station: r.Station{Name: "Bayern 5", CloseDown: "06:00", ProgramURL: urlMustParse("http://www.br.de/radio/b5-aktuell/programmkalender/b5aktuell116.html"), Identifier: identifier, TimeZone: tz}},
		"brheimat": StationBR{Station: r.Station{Name: "BR Heimat", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/br-heimat/programmkalender/br-heimat-116.html"), Identifier: identifier, TimeZone: tz}},
		"puls":     StationBR{Station: r.Station{Name: "Puls", CloseDown: "07:00", ProgramURL: urlMustParse("http://www.br.de/puls/programm/puls-radio/programmkalender/programmfahne104.html"), Identifier: identifier, TimeZone: tz}},
	}[identifier]
	return &s
}

func (s *StationBR) String() string {
	return fmt.Sprintf("Station '%s'", s.Station.Name)
}

func (s *StationBR) parseDayURLsNode(root *html.Node) (ret []*TimeURLBR, err error) {
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

func (s *StationBR) parseDayURLsReader(read io.Reader) (ret []*TimeURLBR, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.parseDayURLsNode(root)
}

func (s *StationBR) parseDayURLs() (ret []*TimeURLBR, err error) {
	resp, err := http.Get(s.ProgramURL.String())
	defer resp.Body.Close()
	if nil != err {
		return
	}
	return s.parseDayURLsReader(resp.Body)
}

// Scrape slice of TimeURLBR - all calendar (day) entries of the station program url
func (s *StationBR) Scrape(jobs chan<- r.Scraper, results chan<- r.Broadcaster) (err error) {
	time_urls, err := s.parseDayURLs()
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

func (s *StationBR) newTimeURL(relUrl string) (ret r.TimeURL, err error) {
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
	ret = r.TimeURL{Time: day, Source: programURL}
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type.
type TimeURLBR struct {
	r.TimeURL
	Station *StationBR
}

// Scrape slice of BroadcastURLBR - all per-day broadcast entries of the day url
func (day *TimeURLBR) Scrape(jobs chan<- r.Scraper, results chan<- r.Broadcaster) (err error) {
	broadcast_urls, err := day.Station.parseBroadcastURLs(&day.Source)
	if nil == err {
		for _, b := range broadcast_urls {
			jobs <- b
		}
	}
	return
}

// 3 days window, 1 day each side.
func (day *TimeURLBR) Matches(now *time.Time) (ok bool) {
	if nil == now || nil == day {
		return false
	}
	dt := day.Time.Sub(*now)
	return -24*time.Hour <= dt && dt <= 24*time.Hour
}

func (s *StationBR) parseBroadcastURLsNode(day_url *url.URL, root *html.Node) (ret []*BroadcastURLBR, err error) {
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
			// fmt.Printf("%s %s\n", b.r.TimeURL.String(), b.Title)
			ret = append(ret, &BroadcastURLBR{BroadcastURL: r.BroadcastURL{
				TimeURL: r.TimeURL{
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

func (s *StationBR) parseBroadcastURLsReader(day_url *url.URL, read io.Reader) (ret []*BroadcastURLBR, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.parseBroadcastURLsNode(day_url, root)
}

func (s *StationBR) parseBroadcastURLs(day_url *url.URL) (ret []*BroadcastURLBR, err error) {
	resp, err := http.Get(day_url.String())
	defer resp.Body.Close()
	if nil != err {
		return
	}
	return s.parseBroadcastURLsReader(day_url, resp.Body)
}

/////////////////////////////////////////////////////////////////////////////
///

type BroadcastURLBR struct {
	r.BroadcastURL
	Station *StationBR
}

func (b *BroadcastURLBR) Scrape(jobs chan<- r.Scraper, results chan<- r.Broadcaster) (err error) {
	bc, err := b.Station.parseBroadcast(&b.TimeURL.Source)
	if nil == err {
		results <- bc
	}
	return
}

// 1h future interval
func (b *BroadcastURLBR) Matches(now *time.Time) (ok bool) {
	start := &b.Time
	if nil == now || nil == start {
		return false
	}
	dt := start.Sub(*now)
	if 0 <= dt && dt <= 60*time.Minute {
		return true
	}
	return false
}

/////////////////////////////////////////////////////////////////////////////
///

var (
	localLoc *time.Location // TODO: abolish, replace with r.Station.TimeZone
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
func (s *StationBR) parseBroadcastNode(url *url.URL, root *html.Node) (bc r.Broadcast, err error) {
	bc.Source = *url
	{
		s := "de"
		bc.Language = &s
	}
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
				s := scrape.Text(span)
				bc.TitleSeries = &s
			case "bcast_subtitle":
				s := scrape.Text(span)
				bc.TitleEpisode = &s
			default:
				err = errors.New("unexpected <span> inside <h1>")
				return
			}
			bc.Title = textChildrenNoClimb(h1)
		}
		{
			// Description
			var desc []string = r.TextsWithBr(scrape.FindAll(h1.Parent, func(n *html.Node) bool { return atom.P == n.DataAtom && "copytext" == scrape.Attr(n, "class") }))
			re := regexp.MustCompile("[ ]*(\\s)") // collapse whitespace, keep \n
			t := strings.Join(desc, "\n\n")       // mark paragraphs with a double \n
			t = re.ReplaceAllString(t, "$1")      // collapse whitespace (not the \n\n however)
			t = strings.TrimSpace(t)
			bc.Description = &t
		}
	FoundImage:
		// test some candidates:
		for _, no := range []*html.Node{h1.Parent, root} {
			for _, di := range scrape.FindAll(no, func(n *html.Node) bool { return atom.Div == n.DataAtom && "picturebox" == scrape.Attr(n, "class") }) {
				for _, img := range scrape.FindAll(di, func(n *html.Node) bool { return atom.Img == n.DataAtom }) {
					u, _ := url.Parse(scrape.Attr(img, "src"))
					bc.Image = u
					break FoundImage
				}
			}
		}
	}

	// Time, DtEnd
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
		bc.Time = time.Date(i(m[3]), time.Month(i(m[2])), i(m[1]), i(m[4]), i(m[5]), 0, 0, localLoc)
		t := time.Date(i(m[3]), time.Month(i(m[2])), i(m[1]), i(m[6]), i(m[7]), 0, 0, localLoc)
		if bc.Time.Hour() > t.Hour() { // after midnight
			t = t.AddDate(0, 0, 1)
		}
		bc.DtEnd = &t
	}

	// Language
	for idx, meta := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.Meta == n.DataAtom && "og:locale" == scrape.Attr(n, "property")
	}) {
		if idx != 0 {
			err = errors.New("There was more than 1 <meta property='og:locale'/>")
			return
		}
		v := scrape.Attr(meta, "content")[0:2]
		bc.Language = &v
	}

	// Subject
	for idx, a := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.A == n.DataAtom && strings.HasPrefix(scrape.Attr(n, "class"), "link_broadcast media_broadcastSeries")
	}) {
		if idx != 0 {
			err = errors.New("There was more than 1 <a class='link_broadcast media_broadcastSeries'/>")
			return
		}
		u := bc.Source
		u.Path = scrape.Attr(a, "href")
		bc.Subject = &u
	}

	// Modified
	for idx, meta := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.Meta == n.DataAtom && "og:article:modified_time" == scrape.Attr(n, "property")
	}) {
		if idx != 0 {
			err = errors.New("There was more than 1 <meta property='og:article:modified_time'/>")
			return
		}
		v, _ := time.Parse(time.RFC3339, scrape.Attr(meta, "content"))
		bc.Modified = &v
	}

	// Author
	for idx, meta := range scrape.FindAll(root, func(n *html.Node) bool {
		return atom.Meta == n.DataAtom && "author" == scrape.Attr(n, "name")
	}) {
		if idx != 0 {
			err = errors.New("There was more than 1 <meta name='author'/>")
			return
		}
		s := scrape.Attr(meta, "content")
		bc.Author = &s
	}

	// Image
	return
}

func (s *StationBR) parseBroadcastReader(url *url.URL, read io.Reader) (bc r.Broadcast, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return s.parseBroadcastNode(url, root)
}

func (s *StationBR) parseBroadcast(url *url.URL) (bc r.Broadcast, err error) {
	resp, err := http.Get(url.String())
	defer resp.Body.Close()
	if nil != err {
		return
	}
	return s.parseBroadcastReader(url, resp.Body)
}
