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
	"net/http"
	"os"
	"time"

	r "purl.mro.name/recorder/radio/scrape"
)

/////////////////////////////////////////////////////////////////////////////
///

/////////////////////////////////////////////////////////////////////////////
/// Just wrap Station into a distinct, local type.
type station struct {
	r.Station
}

// Station Factory
//
// Returns a instance conforming to 'scrape.Scraper'
func Station(identifier string) *station {
	switch identifier {
	case
		"wdr5":
		return &station{Station: r.Station{Name: "WDR 5", CloseDown: "00:00", ProgramURL: r.MustParseURL("http://www.wdr.de/programmvorschau/ajax/wdr5/uebersicht/"), Identifier: identifier, TimeZone: localLoc}}
	}
	return nil
}

func (s *station) String() string {
	return fmt.Sprintf("Station '%s'", s.Station.Name)
}

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
// https://www.wdr.de/programmvorschau/ajax/alle/uebersicht/2016-07-23/
func (s *station) dayURLForDate(day time.Time) (ret *dayUrl, err error) {
	ret = &dayUrl{
		TimeURL: r.TimeURL{
			Time:    time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, s.TimeZone),
			Source:  *r.MustParseURL(s.ProgramURL.String() + day.Format("2006-01-02/")),
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

func (day dayUrl) Matches(now *time.Time) (ok bool) {
	return true
}

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

func (day *dayUrl) parseBroadcastsFromData(programm WdrProgramm) (ret []*r.Broadcast, err error) {
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

func (day *dayUrl) parseBroadcastsFromReader(read io.Reader) (ret []*r.Broadcast, err error) {
	cr := r.NewCountingReader(read)
	var f WdrProgramm
	err = json.NewDecoder(cr).Decode(&f)
	fmt.Fprintf(os.Stderr, "parsed %d bytes\n", cr.TotalBytes)
	if nil != err {
		panic(err)
		return
	}
	return day.parseBroadcastsFromData(f)
}

func (day *dayUrl) parseBroadcastsFromURL() (ret []*r.Broadcast, err error) {
	resp, err := http.Get(day.Source.String())
	if nil != err {
		return
	}
	defer resp.Body.Close()
	return day.parseBroadcastsFromReader(resp.Body)
}
