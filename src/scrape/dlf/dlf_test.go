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
package dlf // import "purl.mro.name/recorder/radio/scrape/dlf"

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	r "purl.mro.name/recorder/radio/scrape"
)

func TestFactory(t *testing.T) {
	s := Station("dlf foo")
	assert.Nil(t, s, "ouch")
	s = Station("dlf")
	assert.NotNil(t, s, "ouch")
	assert.Equal(t, "Deutschlandfunk", s.Name, "ouch")
}

func TestTimeZone(t *testing.T) {
	s := Station("dlf")
	assert.Equal(t, "Europe/Berlin", s.TimeZone.String(), "ouch: TimeZone")
}

func TestDayURLForDate(t *testing.T) {
	s := Station("dlf")
	u, err := s.dayURLForDate(time.Date(2015, 11, 30, 5, 0, 0, 0, s.TimeZone))
	assert.Nil(t, err, "ouch: err")
	assert.Equal(t, "http://www.deutschlandfunk.de/programmvorschau.281.de.html?drbm:date=30.11.2015", u.Source.String(), "ouch")
	assert.Equal(t, "2015-11-30T00:00:00+01:00", u.Time.Format(time.RFC3339), "ouch")
}

func TestParseBroadcasts(t *testing.T) {
	f, err := os.Open("testdata/2015-10-25-dlf-programm.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("dlf")
	u := timeURL(r.TimeURL{
		Time:    time.Date(2015, time.October, 25, 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL("http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=25.10.2015"),
		Station: r.Station(*s),
	})

	bcs, err := u.parseBroadcastsFromReader(f, nil)
	assert.NotNil(t, bcs, "ouch")
	assert.Nil(t, err, "ouch")
	assert.Equal(t, 46, len(bcs), "ouch")
	bc := bcs[0]
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "dlf", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Nachrichten", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=25.10.2015#0000", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, bc.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-10-25T00:00:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.NotNil(t, bc.DtEnd, "ouch: DtEnd")
	assert.Equal(t, "2015-10-25T00:05:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 300*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.NotNil(t, bc.Subject, "ouch: Subject")
	assert.Equal(t, "http://www.deutschlandfunk.de/die-nachrichten.353.de.html", bc.Subject.String(), "ouch: Subject")
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
	assert.Equal(t, "dlf", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Deutschlandfunk Radionacht", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=25.10.2015#0205", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, bc.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-10-25T02:05:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-10-25T06:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 14100*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.NotNil(t, bc.Subject, "ouch: Subject")
	assert.Equal(t, "http://www.deutschlandfunk.de/deutschlandfunk-radionacht.1746.de.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "02:05 Sternzeit\n\n02:07 Konzertmomente\n\nLudwig van Beethoven\nKonzert für Klavier und Orchester Nr. 5 Es-Dur, op. 73\nAcademy of St. Martin-in-the-Fields\nLeitung: Murray Perahia\n\n\n\n03:00 Nachrichten\n\n03:05 Schlüsselwerke\n\nDmitri Schostakowitsch\nStreichquartett Nr. 14, Fis-Dur, op. 142\nBorodin-Quartett\n\n\n\n03:55 Kalenderblatt\n\n04:00 Nachrichten\n\n04:05 Die neue Platte XL\n\nAlte Musik\n\n\n\n05:00 Nachrichten\n\n05:05 Auftakt", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.deutschlandfunk.de/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")
}

func TestParseBroadcasts_1(t *testing.T) {
	f, err := os.Open("testdata/2015-11-14-dlf-programm.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("dlf")
	u := timeURL(r.TimeURL{
		Time:    time.Date(2015, time.November, 14, 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL("http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=14.11.2015"),
		Station: r.Station(*s),
	})

	bcs, err := u.parseBroadcastsFromReader(f, nil)
	assert.NotNil(t, bcs, "ouch")
	assert.Nil(t, err, "ouch")
	assert.Equal(t, 43, len(bcs), "ouch")
	bc := bcs[1]
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "dlf", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Mitternachtskrimi", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.deutschlandfunk.de/programmvorschau.281.de.html?cal:month=10&drbm:date=14.11.2015#0005", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, bc.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-11-14T00:05:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-11-14T01:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 3300*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.NotNil(t, bc.Subject, "ouch: Subject")
	assert.Equal(t, "http://www.deutschlandfunk.de/hoerspiel.687.de.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Nil(t, bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "Gotteskrieger\nVon Christoph Güsken\nRegie: Klaus-Michael Klingsporn\nMusik: Frank Merfort\nMit: Christoph Gawenda, Aylin Esener, Andreas Schmidt, Anita Vulesica, Frank Arnold, Katja Teichmann u.a.\nProduktion: DKultur 2015\nLänge: ca. 54'\n\nNach Terroranschlägen in den europäischen Metropolen gibt es auch in Berlin eine erhöhte Sicherheitsstufe. Die Galerie Schlöndorff steht kurz vor der Eröffnung einer Vernissage mit Werken des Zeichners Laurin Svensson. Vor allem seine Karikatur 'Krisensitzung' hatte im Vorfeld Schlagzeilen gemacht. Das Bild zeigt Jesus, den Propheten Elias und Mohammed bei einem feuchtfröhlichen Abendmahl. Svensson wird auf offener Straße entführt. In einem auf YouTube veröffentlichten Video bekennt sich eine Gruppe namens Deutsches Kalifat zu der Entführung und schließt eine Hinrichtung vor laufender Kamera nicht aus. Dem Leiter der SOKO, Heiko Lübeck, und Hauptkommissarin Aygün Kleist bleiben nur wenige Stunden: Das Ultimatum läuft um Mitternacht ab.\n\nChristoph Güsken, geboren 1958 in Mönchengladbach, lebt in Münster. Zu seinen bekanntesten Werken zählen die Krimis um das Detektivgespann Bernie Kittel und Henk Voss. 2004 produzierte DKultur \"Blaubarts Gärtner\" und 2014 \"Quotenkiller\".", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.deutschlandfunk.de/", *bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")
}
