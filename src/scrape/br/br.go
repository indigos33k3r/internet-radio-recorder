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

// Scrape http://br.de program schedule + broadcast pages.
//
// import "purl.mro.name/recorder/radio/scrape/br"

package br

import (
	"errors"
	"fmt"
	"io"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	r "purl.mro.name/recorder/radio/scrape"
)

/////////////////////////////////////////////////////////////////////////////
///

/////////////////////////////////////////////////////////////////////////////
/// Just wrap Station into a distinct, local type.
type station r.Station

// Station Factory
//
// Returns a instance conforming to 'scrape.Scraper'
func Station(identifier string) *station {
	tz, err := time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
	s := map[string]station{
		"b+":       station(r.Station{Name: "Bayern Plus", CloseDown: "05:00", ProgramURL: r.MustParseURL("http://www.br.de/radio/bayern-plus/programmkalender/bayern-plus114.html"), Identifier: identifier, TimeZone: tz}),
		"b1":       station(r.Station{Name: "Bayern 1", CloseDown: "05:00", ProgramURL: r.MustParseURL("http://www.br.de/radio/bayern1/service/programm/index.html"), Identifier: identifier, TimeZone: tz}),
		"b2":       station(r.Station{Name: "Bayern 2", CloseDown: "05:00", ProgramURL: r.MustParseURL("http://www.br.de/radio/bayern2/service/programm/index.html"), Identifier: identifier, TimeZone: tz}),
		"b5":       station(r.Station{Name: "Bayern 5", CloseDown: "06:00", ProgramURL: r.MustParseURL("http://www.br.de/radio/b5-aktuell/programmkalender/b5aktuell116.html"), Identifier: identifier, TimeZone: tz}),
		"brheimat": station(r.Station{Name: "BR Heimat", CloseDown: "05:00", ProgramURL: r.MustParseURL("http://www.br.de/radio/br-heimat/programmkalender/br-heimat-116.html"), Identifier: identifier, TimeZone: tz}),
		"puls":     station(r.Station{Name: "Puls", CloseDown: "07:00", ProgramURL: r.MustParseURL("http://www.br.de/puls/programm/puls-radio/programmkalender/programmfahne104.html"), Identifier: identifier, TimeZone: tz}),
	}[identifier]
	// fmt.Fprintf(os.Stderr, "             %p %s\n", &s, s.Name)
	return &s
}

func (s *station) String() string {
	return fmt.Sprintf("Station '%s'", s.Name)
}

func (s *station) parseDayURLsNode(root *html.Node) (ret []timeURL, err error) {
	i := 0
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
		ret = append(ret, timeURL(d))
	}
	return
}

func (s *station) parseDayURLsReader(read io.Reader, cr0 *r.CountingReader) (ret []timeURL, err error) {
	cr := r.NewCountingReader(read)
	root, err := html.Parse(cr)
	r.ReportLoad("🐦", cr0, cr, *s.ProgramURL)
	if nil != err {
		return
	}
	ret, err = s.parseDayURLsNode(root)
	return
}

func (s *station) parseDayURLs() (ret []timeURL, err error) {
	bo, cr, err := r.HttpGetBody(*s.ProgramURL)
	if nil == bo {
		return nil, err
	}
	return s.parseDayURLsReader(bo, cr)
}

// Scrape slice of timeURL - all calendar (day) entries of the station program url
func (s *station) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	dayUrls, err := s.parseDayURLs()
	if nil == err {
		for _, v := range dayUrls {
			vv := v
			jobs = append(jobs, &vv)
		}
	}
	return
}

func (s *station) Matches(nows []time.Time) (ok bool) {
	return true
}

var (
	urlDayRegExp *regexp.Regexp = regexp.MustCompile("^/.+~_date-(\\d{4}-\\d{2}-\\d{2})_-[0-9a-f]{40}\\.html$")
)

func (s *station) newTimeURL(relUrl string) (ret r.TimeURL, err error) {
	m := urlDayRegExp.FindStringSubmatch(relUrl)
	if nil == m {
		err = errors.New("Couldn't match regexp on " + relUrl + "")
		return
	}
	dayStr := m[1]

	day, err := time.ParseInLocation("2006-01-02 15:04", dayStr+" "+s.CloseDown, s.TimeZone)
	if nil != err {
		return
	}

	ru, _ := url.Parse(relUrl)
	programURL := *s.ProgramURL.ResolveReference(ru)
	ret = r.TimeURL{Time: day, Source: programURL, Station: r.Station(*s)}
	if "" == ret.Station.Identifier {
		panic("How can the identifier miss?")
	}
	// fmt.Fprintf(os.Stderr, " t %s %s\n", ret.Time.Format(time.RFC3339), ret.Source.String())
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type.
type timeURL r.TimeURL

// Scrape slice of broadcastURL - all per-day broadcast entries of the day url
func (day *timeURL) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	broadcastUrls, err := day.parseBroadcastURLs()
	if nil == err {
		for _, b := range broadcastUrls {
			bb := *b
			jobs = append(jobs, &bb)
		}
	}
	return
}

// 3 days window, 1 day each side.
func (day *timeURL) Matches(nows []time.Time) (ok bool) {
	if nil == nows || nil == day {
		return false
	}
	for _, now := range nows {
		dt := day.Time.Sub(now)
		if -24*time.Hour <= dt && dt <= 24*time.Hour {
			return true
		}
	}
	return false
}

func (day *timeURL) parseBroadcastURLsNode(root *html.Node) (ret []*broadcastURL, err error) {
	const closeDownHour int = 5
	for _, h4 := range scrape.FindAll(root, func(n *html.Node) bool { return atom.H4 == n.DataAtom }) {
		year, month, day2, err := timeForH4(scrape.Text(h4), &day.Time)
		if nil != err {
			panic(err)
		}
		// fmt.Printf("%d-%d-%d %s\n", year, month, day, err)
		for _, a := range scrape.FindAll(h4.Parent, func(n *html.Node) bool { return atom.A == n.DataAtom && atom.Dt == n.Parent.DataAtom }) {
			m := hourMinuteTitleRegExp.FindStringSubmatch(scrape.Text(a))
			if nil == m {
				panic(errors.New("Couldn't parse <a>"))
			}
			ur, _ := url.Parse(scrape.Attr(a, "href"))
			hour := r.MustParseInt(m[1])
			dayOffset := 0
			if hour < closeDownHour {
				dayOffset = 1
			}
			// fmt.Printf("%s %s\n", b.r.TimeURL.String(), b.Title)
			bcu := broadcastURL(r.BroadcastURL{
				TimeURL: r.TimeURL{
					Time:    time.Date(year, month, day2+dayOffset, hour, r.MustParseInt(m[2]), 0, 0, localLoc),
					Source:  *day.Source.ResolveReference(ur),
					Station: day.Station,
				},
				Title: strings.TrimSpace(m[3]),
			})
			ret = append(ret, &bcu)
		}
	}
	return
}

func (day *timeURL) parseBroadcastURLsReader(read io.Reader, cr0 *r.CountingReader) (ret []*broadcastURL, err error) {
	cr := r.NewCountingReader(read)
	root, err := html.Parse(cr)
	r.ReportLoad("🐠", cr0, cr, day.Source)
	if nil != err {
		return
	}
	return day.parseBroadcastURLsNode(root)
}

func (day *timeURL) parseBroadcastURLs() (ret []*broadcastURL, err error) {
	bo, cr, err := r.HttpGetBody(day.Source)
	if nil == bo {
		return nil, err
	}
	return day.parseBroadcastURLsReader(bo, cr)
}

/////////////////////////////////////////////////////////////////////////////
///

/// Just wrap BroadcastURL into a distinct, local type.
type broadcastURL r.BroadcastURL

func (bcu *broadcastURL) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	bcs, err := bcu.parseBroadcastsFromURL()
	if nil == err {
		for _, bc := range bcs {
			results = append(results, bc)
		}
	}
	return
}

// 1h future interval
func (bcu *broadcastURL) Matches(nows []time.Time) (ok bool) {
	start := &bcu.Time
	if nil == nows || nil == start {
		return false
	}
	for _, now := range nows {
		dt := start.Sub(now)
		// fmt.Fprintf(os.Stderr, "*broadcastURL.Matches: %d %d = %s - %s\n", ok, dt, start.Format(time.RFC3339), now.Format(time.RFC3339))
		if 0 <= dt && dt <= 60*time.Minute {
			return true
		}
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
	mon = time.Month(r.MustParseInt(m[2]))
	year = yearForMonth(mon, now)
	day = r.MustParseInt(m[1])
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Parse broadcast
/////////////////////////////////////////////////////////////////////////////

var (
	bcDateRegExp = regexp.MustCompile(",\\s+(\\d{2})\\.(\\d{2})\\.(\\d{4})\\s+(\\d{2}):(\\d{2})\\s+bis\\s+(\\d{2}):(\\d{2})")
)

// Completely re-scrape everything and verify consistence at least of Time, evtl. Title
func (bcu *broadcastURL) parseBroadcastNode(root *html.Node) (bcs []r.Broadcast, err error) {
	var bc r.Broadcast
	bc.Station = bcu.Station
	bc.Source = bcu.Source
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
		bc.Title = r.TextChildrenNoClimb(h1)
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
			bc.Title = r.TextChildrenNoClimb(h1)
		}
		{
			description := r.TextWithBrFromNodeSet(scrape.FindAll(h1.Parent, func(n *html.Node) bool { return atom.P == n.DataAtom && "copytext" == scrape.Attr(n, "class") }))
			bc.Description = &description
		}
		if nil == bc.Image {
		FoundImage0:
			for _, di := range scrape.FindAll(h1.Parent, func(n *html.Node) bool {
				return atom.Div == n.DataAtom && "teaser media_video embeddedMedia" == scrape.Attr(n, "class")
			}) {
				for _, img := range scrape.FindAll(di, func(n *html.Node) bool { return atom.Img == n.DataAtom }) {
					u, _ := url.Parse(scrape.Attr(img, "src"))
					bc.Image = bcu.Source.ResolveReference(u)
					break FoundImage0
				}
			}
		}
		if nil == bc.Image {
		FoundImage1:
			// test some candidates:
			for _, no := range []*html.Node{h1.Parent, root} {
				for _, di := range scrape.FindAll(no, func(n *html.Node) bool { return atom.Div == n.DataAtom && "picturebox" == scrape.Attr(n, "class") }) {
					for _, img := range scrape.FindAll(di, func(n *html.Node) bool { return atom.Img == n.DataAtom }) {
						u, _ := url.Parse(scrape.Attr(img, "src"))
						bc.Image = bcu.Source.ResolveReference(u)
						break FoundImage1
					}
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
		i := r.MustParseInt
		bc.Time = time.Date(i(m[3]), time.Month(i(m[2])), i(m[1]), i(m[4]), i(m[5]), 0, 0, localLoc)
		t := time.Date(i(m[3]), time.Month(i(m[2])), i(m[1]), i(m[6]), i(m[7]), 0, 0, localLoc)
		if bc.Time.Hour() > t.Hour() || (bc.Time.Hour() == t.Hour() && bc.Time.Minute() > t.Minute()) { // after midnight
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
		u, _ := url.Parse(scrape.Attr(a, "href"))
		bc.Subject = bc.Source.ResolveReference(u)
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

	if "" == bc.Station.Identifier {
		panic("How can the identifier miss?")
	}
	bcs = append(bcs, bc)
	return
}

func (bcu *broadcastURL) parseBroadcastReader(read io.Reader, cr0 *r.CountingReader) (bc []r.Broadcast, err error) {
	cr := r.NewCountingReader(read)
	root, err := html.Parse(cr)
	r.ReportLoad("⚓️", cr0, cr, bcu.Source)
	if nil != err {
		return
	}
	return bcu.parseBroadcastNode(root)
}

func (bcu *broadcastURL) parseBroadcastsFromURL() (bc []r.Broadcast, err error) {
	return r.GenericParseBroadcastFromURL(bcu.Source, func(r io.Reader, cr *r.CountingReader) ([]r.Broadcast, error) {
		return bcu.parseBroadcastReader(r, cr)
	})
}
