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
package m945 // import "purl.mro.name/recorder/radio/scrape/m945"

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	r "purl.mro.name/recorder/radio/scrape"
)

func TestFactory(t *testing.T) {
	s := Station("m945 foo")
	assert.Nil(t, s, "ouch")
	s = Station("m945")
	assert.NotNil(t, s, "ouch")
	assert.Equal(t, "M 94.5", s.Name, "ouch")
}

func TestTimeZone(t *testing.T) {
	s := Station("m945")
	assert.Equal(t, "Europe/Berlin", s.TimeZone.String(), "ouch: TimeZone")
}

func TestDayURLForDate(t *testing.T) {
	s := Station("m945")
	u, err := s.dayURLForDate(time.Date(2015, 11, 30, 5, 0, 0, 0, s.TimeZone))
	assert.Nil(t, err, "ouch: err")
	assert.Equal(t, "http://www.m945.de/programm/?daterequest=2015-11-30", u.Source.String(), "ouch")
	assert.Equal(t, "2015-11-30T00:00:00+01:00", u.Time.Format(time.RFC3339), "ouch")
}

/*

func TestParseBroadcasts(t *testing.T) {
	f, err := os.Open("testdata/2015-10-25-m945-programm.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("m945")
	u := timeURL{
		r.TimeURL{
			Time:    time.Date(2015, time.October, 25, 0, 0, 0, 0, s.TimeZone),
			Source:  *r.MustParseURL("http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=25.10.2015"),
			Station: s.Station,
		},
	}

	bcs, err := u.parseBroadcastsFromReader(f)
	assert.NotNil(t, bcs, "ouch")
	assert.Nil(t, err, "ouch")
	assert.Equal(t, 46, len(bcs), "ouch")
	bc := bcs[0]
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "m945", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Nachrichten", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=25.10.2015#0000", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, t0.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-10-25T00:00:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.NotNil(t, bc.DtEnd, "ouch: DtEnd")
	assert.Equal(t, "2015-10-25T00:05:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 300*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.deutschlandfunk.de/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")

	bc = bcs[3]
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "m945", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Deutschlandfunk Radionacht", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=25.10.2015#0205", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, t0.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-10-25T02:05:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-10-25T06:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 14100*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "02:05 Sternzeit\n\n02:07 Konzertmomente\n\nLudwig van Beethoven\nKonzert für Klavier und Orchester Nr. 5 Es-Dur, op. 73\nAcademy of St. Martin-in-the-Fields\nLeitung: Murray Perahia\n\n\n\n03:00 Nachrichten\n\n03:05 Schlüsselwerke\n\nDmitri Schostakowitsch\nStreichquartett Nr. 14, Fis-Dur, op. 142\nBorodin-Quartett\n\n\n\n03:55 Kalenderblatt\n\n04:00 Nachrichten\n\n04:05 Die neue Platte XL\n\nAlte Musik\n\n\n\n05:00 Nachrichten\n\n05:05 Auftakt", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.deutschlandfunk.de/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")
}
*/

func TestParseBroadcasts_1(t *testing.T) {
	f, err := os.Open("testdata/2015-11-14-m945-programm.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("m945")
	u := timeURL(r.TimeURL{
		Time:    time.Date(2015, time.November, 14, 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL("http://www.m945.de/programm/?daterequest=2015-11-14"),
		Station: r.Station(*s),
	})

	bcs, err := u.parseBroadcastsFromReader(f, nil)
	assert.NotNil(t, bcs, "ouch")
	assert.Nil(t, err, "ouch")
	assert.Equal(t, 10, len(bcs), "ouch")

	assert.Equal(t, "Black Box: HipHop", bcs[0].Title, "ouch: Title")
	assert.Equal(t, "Musik 01:00-09:00", bcs[1].Title, "ouch: Title")
	assert.Equal(t, "Hörbar²", bcs[2].Title, "ouch: Title")
	assert.Equal(t, "Katerfrühstück", bcs[3].Title, "ouch: Title")
	assert.Equal(t, "K13", bcs[4].Title, "ouch: Title")
	assert.Equal(t, "Musik 14:00-18:00", bcs[5].Title, "ouch: Title")
	assert.Equal(t, "Störfunk", bcs[6].Title, "ouch: Title")
	assert.Equal(t, "Kanalratten", bcs[7].Title, "ouch: Title")
	assert.Equal(t, "Spurensuche", bcs[8].Title, "ouch: Title")
	assert.Equal(t, "Musik 22:00-00:00", bcs[9].Title, "ouch: Title")

	bc := bcs[1]
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "m945", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Musik 01:00-09:00", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.m945.de/programm/?daterequest=2015-11-14", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, "Musik 01:00-09:00", bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-11-14T01:00:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-11-14T09:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 480*time.Minute, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.m945.de/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")

	bc = bcs[2]
	assert.Equal(t, "m945", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Hörbar²", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.m945.de/programm/?daterequest=2015-11-14", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, "Hörbar²", bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-11-14T09:00:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-11-14T11:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 120*time.Minute, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	//	assert.Equal(t, "http://www.m945.de/content/hoerbar_am_vormittag.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "Moderation: Severin Schenkel", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.m945.de/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")

	bc = bcs[3]
	assert.NotNil(t, bc.Subject, "ouch: Subject")
	assert.Equal(t, "http://www.m945.de/content/katerfruhstuck.html", bc.Subject.String(), "ouch: Subject")
}
