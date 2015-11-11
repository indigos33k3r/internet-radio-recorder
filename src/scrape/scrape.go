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
	"fmt"
	"io"
	"net/url"
	"strconv"
	"time"
)

//////////////////////////////////////////////////////////////////////////////////////////
///
//////////////////////////////////////////////////////////////////////////////////////////
type Station struct {
	Identifier string
	Name       string
	CloseDown  string
	ProgramURL *url.URL
	TimeZone   *time.Location
}

//////////////////////////////////////////////////////////////////////////////////////////
///
//////////////////////////////////////////////////////////////////////////////////////////
type TimeURL struct {
	Time   time.Time
	Source url.URL
}

func (d *TimeURL) String() string {
	return fmt.Sprintf("%s %s", d.Time.Format("2006-01-02 15:04 MST"), d.Source.String())
}

//////////////////////////////////////////////////////////////////////////////////////////
///
//////////////////////////////////////////////////////////////////////////////////////////
type BroadcastURL struct {
	TimeURL
	Title string
}

//////////////////////////////////////////////////////////////////////////////////////////
///
//////////////////////////////////////////////////////////////////////////////////////////
type Broadcast struct {
	BroadcastURL
	TitleSeries  *string
	TitleEpisode *string
	DtEnd        *time.Time
	Modified     *time.Time
	Subject      *url.URL
	Image        *url.URL
	Description  *string
	Author       *string
	Language     *string
	Publisher    *string
	Creator      *string
	Copyright    *string
}

type Broadcaster interface {
	// Broadcast() *Broadcast

	WriteAsLuaTable(w io.Writer) (err error)
}

// func (b Broadcast) Broadcast() *Broadcast { return &b }

func (b Broadcast) WriteAsLuaTable(w io.Writer) (err error) {
	// https://github.com/mro/radio-pi/blob/master/htdocs/app/recorder.rb#L188
	fmt.Fprintf(w, "\n-- comma separated lua tables, one per broadcast:\n{\n")
	fmt.Fprintf(w, "  -- %s = '%s',\n", "t_download_start", "-")
	fmt.Fprintf(w, "  -- %s = '%s',\n", "t_scrape_start", "-")
	fmt.Fprintf(w, "  -- %s = '%s',\n", "t_scrape_end", "-")

	f := func(k string, v string) {
		fmt.Fprintf(w, "  %s = '%s',\n", k, v)
	}
	fp := func(k string, v *string) {
		if nil != v {
			f(k, *v)
		}
	}
	fpu := func(k string, v *url.URL) {
		if nil != v {
			f(k, v.String())
		}
	}
	ft := func(k string, v time.Time) {
		f(k, v.Format(time.RFC3339))
	}

	//	fmt.Fprintf(w, "%s = '%s',\n", "station_name", b.Station.Name)
	f("title", b.Title)
	f("DC_scheme", "/app/pbmi2003-recmod2012/")
	fp("DC_language", b.Language)
	f("DC_title", b.Title)
	fp("DC_title_series", b.TitleSeries)
	fp("DC_title_episode", b.TitleEpisode)
	fpu("DC_subject", b.Subject)
	ft("DC_format_timestart", b.Time)
	if nil != b.DtEnd {
		ft("DC_format_timeend", *b.DtEnd)
		dt := b.DtEnd.Sub(b.Time) / time.Second
		if dt < 0 {
			panic("dt < 0 for " + b.Source.String())
		}
		f("DC_format_duration", strconv.FormatInt(int64(dt), 10))
	}
	fpu("DC_image", b.Image)
	fp("DC_description", b.Description)
	fp("DC_author", b.Author)
	fp("DC_publisher", b.Publisher)
	fp("DC_creator", b.Creator)
	fp("DC_copyright", b.Copyright)
	f("DC_source", b.Source.String())

	fmt.Fprintf(w, "},\n\n")
	return
}

type Scraper interface {
	Scrape(jobs chan<- Scraper, results chan<- Broadcaster) (err error)

	Matches(now *time.Time) (ok bool)
}
