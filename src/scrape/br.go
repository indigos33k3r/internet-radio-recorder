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
	"strings"
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
	tz, err := time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
	switch identifier {
	case "b1":
		return &Station{Name: "Bayern 1", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern1/service/programm/index.html"), Identifier: identifier, TimeZone: tz}
	case "b2":
		return &Station{Name: "Bayern 2", CloseDown: "05:00", ProgramURL: urlMustParse("http://www.br.de/radio/bayern2/service/programm/index.html"), Identifier: identifier, TimeZone: tz}
	case "b5":
		return &Station{Name: "Bayern 5", CloseDown: "06:00", ProgramURL: urlMustParse("http://www.br.de/radio/b5-aktuell/programmkalender/b5aktuell116.html"), Identifier: identifier, TimeZone: tz}
	}
	return nil
}

var (
	localLoc *time.Location // TODO: abolish, replace with station.TimeZone
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

var (
	urlDayRegExp *regexp.Regexp = regexp.MustCompile("^/radio/.+~_date-(\\d{4}-\\d{2}-\\d{2})_-.+$")
)

func newTimeURL(station *Station, relUrl string) *TimeURL {
	m := urlDayRegExp.FindStringSubmatch(relUrl)
	if nil == m {
		return nil
	}
	dayStr := m[1]

	day, err := time.ParseInLocation("2006-01-02 15:04", dayStr+" "+station.CloseDown, station.TimeZone)
	if nil != err {
		panic(err)
	}

	programURL := *(station.ProgramURL)
	programURL.Path = relUrl
	return &TimeURL{Time: day, Source: programURL}
}

func ParseDayURLsNode(station *Station, root *html.Node) (ret []*TimeURL, err error) {
	i := 0
	ret = []*TimeURL{}
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
		ret = append(ret, d)
	}
	return
}

func ParseDayURLsReader(station *Station, read io.Reader) (ret []*TimeURL, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return ParseDayURLsNode(station, root)
}

func ParseDayURLs(station *Station) (ret []*TimeURL, err error) {
	resp, err := http.Get(station.ProgramURL.String())
	if nil != err {
		return
	}
	return ParseDayURLsReader(station, resp.Body)
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

func ParseBroadcastURLsNode(s *Station, url *url.URL, root *html.Node) (ret []*BroadcastURL, err error) {
	ret = []*BroadcastURL{}
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
			ur := *url
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
				Title: strings.TrimSpace(m[3]),
			}
			// fmt.Printf("%s %s\n", b.TimeURL.String(), b.Title)
			ret = append(ret, &b)
		}
	}
	return
}

func ParseBroadcastURLsReader(s *Station, url *url.URL, read io.Reader) (ret []*BroadcastURL, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return ParseBroadcastURLsNode(s, url, root)
}

func ParseBroadcastURLs(s *Station, url *url.URL) (ret []*BroadcastURL, err error) {
	resp, err := http.Get(url.String())
	if nil != err {
		return
	}
	return ParseBroadcastURLsReader(s, url, resp.Body)
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
func ParseBroadcastNode(s *Station, url *url.URL, root *html.Node) (bc Broadcast, err error) {
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

func ParseBroadcastReader(s *Station, url *url.URL, read io.Reader) (bc Broadcast, err error) {
	root, err := html.Parse(read)
	if nil != err {
		return
	}
	return ParseBroadcastNode(s, url, root)
}

func ParseBroadcast(s *Station, url *url.URL) (bc Broadcast, err error) {
	resp, err := http.Get(url.String())
	if nil != err {
		return
	}
	return ParseBroadcastReader(s, url, resp.Body)
}

/////////////////////////////////////////////////////////////////////////////
///
/////////////////////////////////////////////////////////////////////////////

func runScrapeJob(j Job, js chan<- Job, c chan<- Broadcast) {
	switch {
	case nil == j.ScrapeURL:
		// scrape a program (entry) page
		tus, _ := ParseDayURLs(j.Station)
		for i := len(tus) - 1; i >= 0; i-- {
			fmt.Println("%s\n", tus[i].String())
			j1 := j
			j1.ScrapeURL = &tus[i].Source
			js <- j1
		}
	case false == strings.Contains(j.ScrapeURL.String(), "/programmkalender/ausstrahlung-"):
		// scrape a program (daily) page
		bcs, _ := ParseBroadcastURLs(j.Station, j.ScrapeURL)
		for i := len(bcs) - 1; i >= 0; i-- {
			fmt.Println("%s\n", bcs[i].String())
			j1 := j
			j1.ScrapeURL = &bcs[i].Source
			js <- j1
		}
	default:
		// scrape a broadcast page
		bc, _ := ParseBroadcast(j.Station, j.ScrapeURL)
		c <- bc
	}
}
