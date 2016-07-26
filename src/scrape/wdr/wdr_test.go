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

// http://golang.org/pkg/testing/
// http://blog.stretchr.com/2014/03/05/test-driven-development-specifically-in-golang/
// https://xivilization.net/~marek/blog/2015/05/04/go-1-dot-4-2-for-raspberry-pi/
package wdr // import "purl.mro.name/recorder/radio/scrape/wdr"

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	r "purl.mro.name/recorder/radio/scrape"
)

func TestTimeZone(t *testing.T) {
	wdr := Station("wdr5")
	assert.Equal(t, "Europe/Berlin", wdr.TimeZone.String(), "foo")
}

func TestUnmarshalBroadcasts(t *testing.T) {
	f, err := os.Open("testdata/2016-07-25T1207-program.json")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("wdr5")
	u := dayUrl(r.TimeURL{
		Time:    time.Date(2015, time.October, 25, 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL("http://www.wdr.de/programmvorschau/ajax/wdr5/uebersicht/2016-07-25/"),
		Station: r.Station(*s),
	})

	res, err := u.parseBroadcastsFromReader(f)
	assert.Equal(t, 86, len(res), "53")
	bc := res[0]

	assert.Nil(t, err, "ouch")
	assert.Equal(t, "wdr5", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "WDR Aktuell", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-25/40944229/wdr-aktuell.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-07-25T00:00:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-07-25T00:05:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.Equal(t, "", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
}
