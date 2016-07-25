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
package b3 // import "purl.mro.name/recorder/radio/scrape/b3"

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	r "purl.mro.name/recorder/radio/scrape"
)

func TestTimeZone(t *testing.T) {
	b3 := Station("b3")
	assert.Equal(t, "Europe/Berlin", b3.TimeZone.String(), "foo")
}

func TestUnmarshalBroadcasts(t *testing.T) {
	f, err := os.Open("testdata/2016-07-25T0945-program.json")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("b3")
	u := calItemRangeURL{r.TimeURL{
		Time:    time.Now(),
		Source:  *s.Station.ProgramURL,
		Station: s.Station,
	}}

	res, err := u.parseBroadcastsReader(f)
	assert.Equal(t, 3, len(res), "53")
	bc := res[0]

	assert.Nil(t, err, "ouch")
	assert.Equal(t, "b3", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Die Frühaufdreher", bc.Title, "ouch: Title")
	assert.Equal(t, "https://www.br.de/mediathek/audio/bayern3-audio-livestream-100~radioplayer.json", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-07-25T05:00:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-07-25T09:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Equal(t, "Bayerischer Rundfunk", *bc.Author, "ouch: Author")
	assert.Nil(t, bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
}
