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

// Generic stuff useful for scraping radio broadcast station program
// websites.
//
// Most important are the two interfaces 'Scraper' and 'Broadcaster'.
//
// import "purl.mro.name/recorder/radio/scrape"

package scrape

import (
	"fmt"
	"io"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

// Something that can be scraped.
type Scraper interface {
	Scrape() (jobs []Scraper, results []Broadcaster, err error)

	// is (re-)scraping due for this entity?
	Matches(nows []time.Time) (ok bool)
}

// Something that can write broadcast(s) dataset to a writer.
type Broadcaster interface {
	// Do as the name indicates.
	WriteAsLuaTable(w io.Writer) (err error)
}

func (b Broadcast) WriteAsLuaTable(w io.Writer) (err error) {
	if "" == b.Station.Identifier {
		panic("How can the identifier miss?")
	}
	// https://github.com/mro/radio-pi/blob/master/htdocs/app/recorder.rb#L188
	fmt.Fprintf(w, "\n-- comma separated lua tables, one per broadcast:\n{\n")
	fmt.Fprintf(w, "  -- %s = '%s',\n", "t_download_start", "-")
	fmt.Fprintf(w, "  -- %s = '%s',\n", "t_scrape_start", "-")
	fmt.Fprintf(w, "  -- %s = '%s',\n", "t_scrape_end", "-")

	f := func(k string, v string) {
		fmt.Fprintf(w, "  %s = '%s',\n", k, EscapeForLua(v))
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

	f("station", b.Station.Identifier)
	f("title", b.Title)
	f("DC_scheme", "/app/pbmi2003-recmod2012/")
	fp("DC_language", b.Language)
	f("DC_title", b.Title)
	fp("DC_title_series", b.TitleSeries)
	fp("DC_title_episode", b.TitleEpisode)
	fpu("DC_subject", b.Subject)
	ft("DC_formatTimeStart", b.Time)
	if nil != b.DtEnd {
		ft("DC_formatTimeEnd", *b.DtEnd)
		dt := b.DtEnd.Sub(b.Time) / time.Second
		if dt < 0 {
			panic("dt < 0 for " + b.Source.String())
		}
		f("DC_formatDuration", strconv.FormatInt(int64(dt), 10))
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

//////////////////////////////////////////////////////////////////////////////////////////
/// A counting reader (for download I/O stats)
//////////////////////////////////////////////////////////////////////////////////////////

type CountingReader struct {
	reader     io.Reader
	TotalBytes int64
}

func NewCountingReader(r io.Reader) *CountingReader {
	return &CountingReader{reader: r}
}

func (cr *CountingReader) Read(p []byte) (n int, err error) {
	n, err = cr.reader.Read(p)
	cr.TotalBytes += int64(n)
	return
}

func ReportLoad(marker string, cr0 *CountingReader, cr *CountingReader, url url.URL) {
	loaded := int64(0)
	if nil != cr0 {
		loaded = cr0.TotalBytes
	}
	fmt.Fprintf(os.Stderr, "loaded %d B parsed %d B %s %s\n", loaded, cr.TotalBytes, marker, url.String())
}

//////////////////////////////////////////////////////////////////////////////////////////
/// Some Helpers that may be useful but are totally optional.
//////////////////////////////////////////////////////////////////////////////////////////

// Instances of time.Time when incremental scrapes are due.
func IncrementalNows(now time.Time) (ret []time.Time) {
	src := []time.Duration{0, 12, 3 * 24, 7 * 24, 7 * 7 * 24}
	ret = make([]time.Time, len(src))
	for i, h := range src {
		ret[i] = now.Add(h * time.Hour)
	}
	return
}

// Basic data about broadcasting stations.
// Optional, but may be useful to most scrapers.
type Station struct {
	Identifier string
	Name       string
	CloseDown  string
	ProgramURL *url.URL
	TimeZone   *time.Location
}

// Basic data about a url connected with a time.Time.
// May be e.g. a daily schedule or a broadcast detail page.
//
// Optional, but may be useful to most scrapers.
type TimeURL struct {
	time.Time
	Source url.URL
	Station
}

func (d *TimeURL) String() string {
	return fmt.Sprintf("%s %p %s", d.Time.Format("2006-01-02 15:04 MST"), d, d.Source.String())
}

// Basic data about a url connected with a boadcast.
// May be e.g. a broadcast detail page.
//
// Optional, but may be useful to some scrapers.
type BroadcastURL struct {
	TimeURL
	Title string
}

// Data about one broadcast. Ready to be fed to a
// 'Broadcaster'
//
// Optional, but may be useful to most scrapers.
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

func MustParseURL(s string) *url.URL {
	ret, err := url.Parse(s)
	if nil != err {
		panic(err)
	}
	return ret
}

func MustParseInt(s string) int {
	ret, err := strconv.ParseInt(s, 10, 12)
	if nil != err {
		panic(err)
	}
	return int(ret)
}

func MustParseInt64(s string) int64 {
	ret, err := strconv.ParseInt(s, 10, 12)
	if nil != err {
		panic(err)
	}
	return ret
}

func EscapeForLua(s string) string {
	return strings.Replace(strings.Replace(s, "'", "\\'", -1), "\n", "\\n", -1)
}
