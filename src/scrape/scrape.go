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
	"net/url"
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
	// Language     string
}

type Broadcaster interface {
	Broadcast() *Broadcast
}

func (b Broadcast) Broadcast() *Broadcast {
	return &b
}

type Scraper interface {
	Scrape(results chan<- Broadcaster, jobs chan<- Scraper, now *time.Time) (err error)
	Matches(now *time.Time) (ok bool)
}
