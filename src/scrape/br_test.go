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

// http://golang.org/pkg/testing/
// http://blog.stretchr.com/2014/03/05/test-driven-development-specifically-in-golang/
// https://xivilization.net/~marek/blog/2015/05/04/go-1-dot-4-2-for-raspberry-pi/
package scrape // import "purl.mro.name/recorder/radio/scrape"

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

var _ = fmt.Printf

func TestNormalizeTimeOverflow(t *testing.T) {
	{
		t0 := time.Date(2015, 11, 30+1, 5, 0, 0, 0, localLoc)
		assert.Equal(t, "2015-12-01T05:00:00+01:00", t0.Format(time.RFC3339), "oha")
	}
	{
		t0 := time.Date(2015, 11, 30, 24, 0, 0, 0, localLoc)
		assert.Equal(t, "2015-12-01T00:00:00+01:00", t0.Format(time.RFC3339), "oha")
	}
	{
		t0 := time.Date(2015, 11, 30, 24, 1, 0, 0, localLoc)
		assert.Equal(t, "2015-12-01T00:01:00+01:00", t0.Format(time.RFC3339), "oha")
	}
}

func TestYearForMonth(t *testing.T) {
	now := time.Date(2015, 11, 30, 5, 0, 0, 0, localLoc)
	assert.Equal(t, 11, int(now.Month()), "Nov")
	assert.Equal(t, 17, int(now.Month())+6, "Nov")
	assert.Equal(t, 2015, yearForMonth(time.June, &now), "Jun")
	assert.Equal(t, 2015, yearForMonth(time.July, &now), "Jul")
	assert.Equal(t, 2015, yearForMonth(time.August, &now), "Aug")
	assert.Equal(t, 2015, yearForMonth(time.September, &now), "Sept")
	assert.Equal(t, 2015, yearForMonth(time.October, &now), "Oct")
	assert.Equal(t, 2015, yearForMonth(time.November, &now), "Nov")
	assert.Equal(t, 2015, yearForMonth(time.December, &now), "Dec")
	assert.Equal(t, 2016, yearForMonth(time.January, &now), "Jan")
	assert.Equal(t, 2016, yearForMonth(time.February, &now), "Feb")
	assert.Equal(t, 2016, yearForMonth(time.March, &now), "Mar")
	assert.Equal(t, 2016, yearForMonth(time.April, &now), "Apr")
	assert.Equal(t, 2016, yearForMonth(time.May, &now), "May")
}

func TestTimeForH4(t *testing.T) {
	now := time.Date(2015, 11, 30, 5, 0, 0, 0, localLoc)
	year, month, day, err := timeForH4("Morgen\n,\n31.12.", &now)
	assert.Equal(t, 2015, year, "ouch")
	assert.Equal(t, time.December, month, "ouch")
	assert.Equal(t, 31, day, "ouch")
	assert.Nil(t, err, "ouch")

	year, month, day, err = timeForH4("Gestern, 17.02.", &now)
	assert.Equal(t, 2016, year, "ouch")
	assert.Equal(t, time.February, month, "ouch")
	assert.Equal(t, 17, day, "ouch")
	assert.Nil(t, err, "ouch")
}

func TestFileOpen(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21-b2-program.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")
}

func TestParseCalendarForDayURLs(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21-b2-program.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	b2 := StationBR("b2")
	c := make(chan TimeURL, 200)
	ParseDayURLsReader(b2, f, c)
	close(c)
	assert.Equal(t, 37, len(c), "ouch")
}

func TestParseScheduleForBroadcasts(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21-b2-program.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	t0 := TimeURL{
		Time:   time.Date(2015, time.October, 21, 5, 0, 0, 0, localLoc),
		Source: *urlMustParse("http://www.br.de/radio/bayern2/programmkalender/programmfahne102~_date-2015-10-21_-5ddeec3fc12bdd255a6c45c650f068b54f7b010b.html"),
	}
	c := make(chan BroadcastURL, 200)
	ParseBroadcastURLsReader(t0, f, c)
	close(c)
	assert.Equal(t, 129, len(c), "ouch")
}

func TestParseBroadcast(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21T0012-b2-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	t0 := BroadcastURL{
		TimeURL: TimeURL{
			Time:   time.Date(2015, time.October, 21, 5, 0, 0, 0, localLoc),
			Source: *urlMustParse("http://www.br.de/radio/bayern2/programmkalender/programmfahne102~_date-2015-10-21_-5ddeec3fc12bdd255a6c45c650f068b54f7b010b.html"),
		},
		Title: "foo",
	}

	bc := ParseBroadcastReader(t0, f)
	assert.NotNil(t, bc, "ouch")

	assert.Equal(t, "foo", t0.Title, "ouch")
}
