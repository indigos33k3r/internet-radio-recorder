// Copyright (c) 2015-2016 Marcus Rohrmoser, http://purl.mro.name/recorder
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
package radiofabrik // import "purl.mro.name/recorder/radio/scrape/radiofabrik"

import (
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	r "purl.mro.name/recorder/radio/scrape"
)

func TestFactory(t *testing.T) {
	s := Station("dlf foo")
	assert.Nil(t, s, "ouch")
	s = Station("radiofabrik")
	assert.NotNil(t, s, "ouch")
	assert.Equal(t, "radiofabrik", s.Name, "ouch")
}

func TestTimeZone(t *testing.T) {
	s := Station("radiofabrik")
	assert.Equal(t, "Europe/Berlin", s.TimeZone.String(), "ouch: TimeZone")
}

func TestDayURLForDate(t *testing.T) {
	s := Station("radiofabrik")
	u, err := s.dayURLForDate(time.Date(2016, 3, 9, 5, 0, 0, 0, s.TimeZone))
	assert.Nil(t, err, "ouch: err")
	assert.Equal(t, "http://www.radiofabrik.at/programm0/tagesprogramm.html?foo=bar&si_day=09&si_month=03&si_year=2016", u.Source.String(), "ouch")
	assert.Equal(t, "2016-03-09T00:00:00+01:00", u.Time.Format(time.RFC3339), "ouch")
	m, err := url.ParseQuery(u.Source.String())
	assert.Nil(t, err, "ouch: err")
	assert.Equal(t, "09", m.Get("si_day"), "ouch: si_day")
	assert.Equal(t, "03", m.Get("si_month"), "ouch: si_month")
	assert.Equal(t, "2016", m.Get("si_year"), "ouch: si_year")
}

func TestParseBroadcasts(t *testing.T) {
	f, err := os.Open("testdata/2016-03-05-radiofabrik-programm.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("radiofabrik")
	u := timeURL(r.TimeURL{
		Time:    time.Date(2016, time.March, 5, 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL("http://www.radiofabrik.at/programm0/tagesprogramm.html?foo=bar&si_day=05&si_month=03&si_year=2016"),
		Station: r.Station(*s),
	})

	bcs, err := u.parseBroadcastsFromReader(f)
	assert.NotNil(t, bcs, "ouch")
	assert.Nil(t, err, "ouch")
	assert.Equal(t, 28, len(bcs), "ouch")
	bc := bcs[0]
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "radiofabrik", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "My Favourite Music. With David Hubble", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.radiofabrik.at/programm0/tagesprogramm.html?foo=bar&si_day=05&si_month=03&si_year=2016", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, bc.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-03-05T01:00:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.NotNil(t, bc.DtEnd, "ouch: DtEnd")
	assert.Equal(t, "2016-03-05T02:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 3600*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.NotNil(t, bc.Subject, "ouch: Subject")
	assert.Equal(t, "http://www.radiofabrik.at/index.php?id=345", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.radiofabrik.at/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")

	bc = bcs[27]
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "radiofabrik", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Night Shift Radio - Musik - damit die Glotze ausbleibt", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.radiofabrik.at/programm0/tagesprogramm.html?foo=bar&si_day=05&si_month=03&si_year=2016", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, bc.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-03-05T22:00:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-03-06T00:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 7200*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.NotNil(t, bc.Subject, "ouch: Subject")
	assert.Equal(t, "http://www.radiofabrik.at/programm0/sendungenvona-z/night-shift-radio.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.radiofabrik.at/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")
}
