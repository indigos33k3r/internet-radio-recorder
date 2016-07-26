// Copyright (c) 2016-2016 Marcus Rohrmoser, http://purl.mro.name/recorder
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

// Scrape http://bayern3.de program.
//
// import "purl.mro.name/recorder/radio/scrape/b3"
package b3

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

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
	switch identifier {
	case
		"b3":
		s := station(r.Station{Name: "Bayern 3", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.br.de/mediathek/audio/bayern3-audio-livestream-100~radioplayer.json"), Identifier: identifier, TimeZone: localLoc})
		return &s
	}
	return nil
}

func (s *station) String() string {
	return fmt.Sprintf("Station '%s'", s.Name)
}

func (s *station) Matches(nows []time.Time) (ok bool) {
	return true
}

// queue one scrape job: now!
func (s *station) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	i := calItemRangeURL(r.TimeURL{
		Time:    time.Now(),
		Source:  *s.ProgramURL,
		Station: r.Station(*s),
	})
	jobs = append(jobs, &i)
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type - a Scraper, naturally
type calItemRangeURL r.TimeURL

func (url *calItemRangeURL) Matches(nows []time.Time) (ok bool) {
	return true
}

func (url *calItemRangeURL) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	bcs, err := url.parseBroadcasts()
	if nil == err {
		for _, bc := range bcs {
			results = append(results, bc)
		}
	}
	return
}

var (
	localLoc *time.Location
)

func init() {
	var err error
	localLoc, err = time.LoadLocation("Europe/Berlin")
	if nil != err {
		panic(err)
	}
}

/////////////////////////////////////////////////////////////////////////////
/// Parse broadcasts
/////////////////////////////////////////////////////////////////////////////

type B3Programm struct {
	Broadcasts []struct {
		Headline  string
		StartTime string
		EndTime   string
	}
}

func (bcu *calItemRangeURL) parseBroadcastsFromData(programm B3Programm) (bcs []r.Broadcast, err error) {
	language := "de"
	author := "Bayerischer Rundfunk"
	empty := ""
	for _, b3 := range programm.Broadcasts {
		// fill one broadcast from JSON to r.Broadcast
		b := r.Broadcast{
			BroadcastURL: r.BroadcastURL{
				TimeURL: r.TimeURL{
					Station: bcu.Station,
					Source:  bcu.Source},
			},
			Language: &language,
			Author:   &author,
			// Creator:  &bcu.Station.Name,
			// Copyright: &bcu.Station.Name,
			Description: &empty,
		}
		{ // Title
			title := b3.Headline
			if strings.HasPrefix(title, "BAYERN 3 - ") {
				title = title[len("BAYERN 3 - "):len(title)]
			}
			if strings.HasPrefix(title, "BAYERN 3 ") {
				title = title[len("BAYERN 3 "):len(title)]
			}
			b.BroadcastURL.Title = title
		}
		{ // Time (start)
			start, err0 := time.Parse(time.RFC3339, b3.StartTime)
			err = err0
			if nil != err {
				continue
			}
			b.BroadcastURL.TimeURL.Time = start
		}
		{ // DtEnd
			end, err1 := time.Parse(time.RFC3339, b3.EndTime)
			err = err1
			if nil != err {
				continue
			}
			b.DtEnd = &end
		}
		bcs = append(bcs, b)
	}
	return
}

func (url *calItemRangeURL) parseBroadcastsReader(read io.Reader) (bcs []r.Broadcast, err error) {
	cr := r.NewCountingReader(read)
	var f B3Programm
	err = json.NewDecoder(cr).Decode(&f)
	fmt.Fprintf(os.Stderr, "parsed %d bytes 🐦 %s\n", cr.TotalBytes, url.Source.String())
	if nil != err {
		panic(err)
		return
	}
	return url.parseBroadcastsFromData(f)
}

func (url *calItemRangeURL) parseBroadcasts() (bcs []r.Broadcast, err error) {
	resp, err := http.Get(url.Source.String())
	if nil != err {
		return
	}
	defer resp.Body.Close()
	return url.parseBroadcastsReader(resp.Body)
}
