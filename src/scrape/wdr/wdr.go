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

// Scrape wdr schedule.
//
// import "purl.mro.name/recorder/radio/scrape/wdr"
package wdr

import (
	"encoding/json"
	"fmt"
	"io"
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
		"wdr5":
		s := station(r.Station{Name: "WDR 5", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.wdr.de/programmvorschau/ajax/wdr5/uebersicht/"), Identifier: identifier, TimeZone: localLoc})
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

// Synthesise the day urls for incremental scraping.
func (s *station) Scrape() (jobs []r.Scraper, results []r.Broadcaster, err error) {
	now := time.Now()
	for _, t0 := range r.IncrementalNows(now) {
		day, _ := s.dayURLForDate(t0)
		jobs = append(jobs, r.Scraper(*day))
	}
	return
}

///////////////////////////////////////////////////////////////////////
// https://www.wdr.de/programmvorschau/ajax/alle/uebersicht/2016-07-23/
func (s *station) dayURLForDate(day time.Time) (ret *timeURL, err error) {
	r := timeURL(r.TimeURL{
		Time:    time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL(s.ProgramURL.String() + day.Format("2006-01-02/")),
		Station: r.Station(*s),
	})
	ret = &r
	// err = errors.New("Not ümplemented yet.")
	return
}

/////////////////////////////////////////////////////////////////////////////
/// Just wrap TimeURL into a distinct, local type - a Scraper, naturally
type timeURL r.TimeURL

func (day timeURL) Matches(nows []time.Time) (ok bool) {
	return true
}

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

type WdrProgramm struct {
	Sendungen []struct {
		Start      int64
		Ende       int64
		EpgLink    string
		HauptTitel string
	}
}

func (day *timeURL) parseBroadcastsFromData(programm WdrProgramm) (ret []*r.Broadcast, err error) {
	lang_de := "de"
	publisher := "Westdeutscher Rundfunk"
	empty := ""
	for _, b := range programm.Sendungen {
		bc := r.Broadcast{
			BroadcastURL: r.BroadcastURL{
				TimeURL: r.TimeURL{
					Source:  *day.Source.ResolveReference(r.MustParseURL(b.EpgLink)),
					Time:    time.Unix(b.Start/1000, 0),
					Station: day.Station,
				},
				Title: b.HauptTitel,
			},
			Language:    &lang_de,
			Publisher:   &publisher,
			Description: &empty,
		}
		{
			t := time.Unix(b.Ende/1000, 0)
			bc.DtEnd = &t
		}

		ret = append(ret, &bc)
	}
	return
}

func (day *timeURL) parseBroadcastsFromReader(read io.Reader, cr0 *r.CountingReader) (ret []*r.Broadcast, err error) {
	cr := r.NewCountingReader(read)
	var f WdrProgramm
	err = json.NewDecoder(cr).Decode(&f)
	r.ReportLoad("🐦", cr0, cr, day.Source)
	if nil != err {
		return
	}
	return day.parseBroadcastsFromData(f)
}

func (day *timeURL) parseBroadcastsFromURL() (ret []*r.Broadcast, err error) {
	bo, cr, err := r.HttpGetBody(day.Source)
	if nil == bo {
		return nil, err
	}
	return day.parseBroadcastsFromReader(bo, cr)
}
