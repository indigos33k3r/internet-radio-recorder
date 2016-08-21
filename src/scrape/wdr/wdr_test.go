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

func TestUnmarshalBroadcastsFromJSON(t *testing.T) {
	f, err := os.Open("testdata/2016-07-25T1207-program.json")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("wdr5")
	u := timeURL(r.TimeURL{
		Time:    time.Date(2015, time.October, 25, 0, 0, 0, 0, s.TimeZone),
		Source:  *r.MustParseURL("http://www.wdr.de/programmvorschau/ajax/wdr5/uebersicht/2016-07-25/"),
		Station: r.Station(*s),
	})

	res, err := u.parseBroadcastsFromJsonReader(f, nil)
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

func TestUnmarshalBroadcastFromHTML_0(t *testing.T) {
	f, err := os.Open("testdata/2016-07-23T1705-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("wdr5")
	lang := "de"
	dtEnd, _ := time.Parse(time.RFC3339, "2016-07-23T18:00:00+02:00")
	bc0 := broadcast(r.Broadcast{
		BroadcastURL: r.BroadcastURL{
			TimeURL: r.TimeURL{
				Time:    time.Date(2016, time.July, 23, 17, 5, 0, 0, s.TimeZone),
				Source:  *r.MustParseURL("http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html"),
				Station: r.Station(*s),
			},
			Title: "Krimi am Samstag",
		},
		Language: &lang,
		DtEnd:    &dtEnd,
	})

	res, err := bc0.parseBroadcastFromHtmlReader(f, nil)
	assert.Equal(t, 1, len(res), "96")
	bc := res[0]

	assert.Nil(t, err, "ouch")
	assert.Equal(t, "wdr5", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Krimi am Samstag", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Der Knochenmann", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-07-23T17:05:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-07-23T18:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, "http://www1.wdr.de/radio/wdr5/sendungen/krimi-am-samstag/uebersicht-krimi-am-samstag100.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Equal(t, "WDR", *bc.Author, "ouch: Author")
	assert.Equal(t, "Von Wolf Haas\nKomposition: Otto Lechner\nBearbeitung und Regie: Götz Fritsch\nHaas: Wolfram Berger\nBrenner: Erwin Steinhauer\nLöschenkohl: Peter Simonischek\nFerdl: Peter Strauß\nKellnerin: Anna Mertin\nMilovic: Stefan Terdy\nPaul Löschenkohl: Ernst Prassel\nPeter Nidetzky: Peter Nidetzky\nJacky: Harald Pichlhöfer\nRothaarige: Brigitte Soucek\nPalfinger: Erhard Koren\nSchwester: Brigitte Karner\nKrennek: Peter Uray\nHelene: Michou Friesz\nFrau Trummer: Gerti Pall\nKellnerin: Anne Mertin\nFerner wirken mit: Alex Schoeler-Haring, Stefan Puntigam, Ursula\nMihelic-Korp, Johannes Monschein, Netta Goldfarb, Heinrich\nHerki-Hoefler, Horst Klaus, Hertha Block, Friedrich Weidisch, Edith\nUnger, Josef Safranek und Margaret Reschreiter\nMusiker: Georg Graf, Saxofon, Klarinette und Oboe; Herbert Reisinger und\nJoão de Bruçó, Schlagzeug; Anton Burger, Geige; Max Nagl, Saxofon\nAufnahme ORF/MDR\n\nJetzt ist schon wieder was passiert. Privatdetektiv Brenner ist erneut im Einsatz. Krimiautor Wolf Haas schickt ihn diesmal zum wenig idyllischen Grillkönig in die Steiermark - und lässt dabei nicht nur Brathähnchen um Kopf und Kragen fürchten.", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
}

func TestUnmarshalBroadcastFromHTML_1(t *testing.T) {
	f, err := os.Open("testdata/2016-08-21T1705-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("wdr5")
	lang := "de"
	dtEnd, _ := time.Parse(time.RFC3339, "2016-08-21T18:00:00+02:00")
	bc0 := broadcast(r.Broadcast{
		BroadcastURL: r.BroadcastURL{
			TimeURL: r.TimeURL{
				Time:    time.Date(2016, time.August, 21, 17, 5, 0, 0, s.TimeZone),
				Source:  *r.MustParseURL("http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html"),
				Station: r.Station(*s),
			},
			Title: "Krimi am Samstag",
		},
		Language: &lang,
		DtEnd:    &dtEnd,
	})

	res, err := bc0.parseBroadcastFromHtmlReader(f, nil)
	assert.Equal(t, 1, len(res), "96")
	bc := res[0]

	assert.Nil(t, err, "ouch")
	assert.Equal(t, "wdr5", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Krimi am Samstag", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Mördergrube", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-08-21T17:05:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-08-21T18:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, "http://www1.wdr.de/radio/wdr5/sendungen/hoerspiel-am-sonntag/uebersicht-hoerspiel-am-sonntag100.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Equal(t, "WDR", *bc.Author, "ouch: Author")
	assert.Equal(t, "Von Lorenz Schröter\nAndré: Christoph Bach\nBeatrice: Mira Partecke\nDaniela: Victoria Trauttmansdorff\nEinar: Christof Wackernagel\nAndré, jung: Jakob Göss\nBruno: Volker Lippmann\nWaldemar: Gunnar Kolb\nMelanie: Julia Riedler\nJunger Mann: Julius Schleheck\nImke: Claudia Mischke\nRegie: Thomas Wolfertz\n\nDas Leben ist eine Sickergrube voller Erinnerungen. Aber was macht man, wenn der Gestank nicht mehr auszuhalten ist? André beschließt, den Sumpf auszuheben.", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
}

func TestUnmarshalBroadcastFromHTML_2(t *testing.T) {
	f, err := os.Open("testdata/2016-08-21T1800-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("wdr5")
	lang := "de"
	dtEnd, _ := time.Parse(time.RFC3339, "2016-08-21T18:05:00+02:00")
	bc0 := broadcast(r.Broadcast{
		BroadcastURL: r.BroadcastURL{
			TimeURL: r.TimeURL{
				Time:    time.Date(2016, time.August, 21, 18, 0, 0, 0, s.TimeZone),
				Source:  *r.MustParseURL("http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html"),
				Station: r.Station(*s),
			},
			Title: "Krimi am Samstag",
		},
		Language: &lang,
		DtEnd:    &dtEnd,
	})

	res, err := bc0.parseBroadcastFromHtmlReader(f, nil)
	assert.Equal(t, 1, len(res), "96")
	bc := res[0]

	assert.Nil(t, err, "ouch")
	assert.Equal(t, "wdr5", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Krimi am Samstag", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-08-21T18:00:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-08-21T18:05:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Equal(t, "WDR", *bc.Author, "ouch: Author")
	assert.Equal(t, "", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
}

func TestUnmarshalBroadcastFromHTML_3(t *testing.T) {
	f, err := os.Open("testdata/2016-08-21T1805-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("wdr5")
	lang := "de"
	dtEnd, _ := time.Parse(time.RFC3339, "2016-08-21T19:00:00+02:00")
	bc0 := broadcast(r.Broadcast{
		BroadcastURL: r.BroadcastURL{
			TimeURL: r.TimeURL{
				Time:    time.Date(2016, time.August, 21, 18, 5, 0, 0, s.TimeZone),
				Source:  *r.MustParseURL("http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html"),
				Station: r.Station(*s),
			},
			Title: "Krimi am Samstag",
		},
		Language: &lang,
		DtEnd:    &dtEnd,
	})

	res, err := bc0.parseBroadcastFromHtmlReader(f, nil)
	assert.Equal(t, 1, len(res), "96")
	bc := res[0]

	assert.Nil(t, err, "ouch")
	assert.Equal(t, "wdr5", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Krimi am Samstag", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.wdr.de/programmvorschau/wdr5/sendung/2016-07-23/40920025/krimi-am-samstag.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Ich war für viele die Millowitsch-Tochter", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-08-21T18:05:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-08-21T19:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, "http://www1.wdr.de/radio/wdr5/sendungen/erlebtegeschichten/uebersicht-erlebte-geschichten100.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Equal(t, "WDR", *bc.Author, "ouch: Author")
	assert.Equal(t, "Lotti Krekel, Schauspielerin und Sängerin\nVon Christian Geuenich\nWiederholung: 22.05 Uhr\n\nLotti Krekel, am 23. August 1941 in Roetgen in der Eifel geboren, war ein Kinderstar des Radios. Dort lernte sie Willy Millowitsch kennen und wurde später als seine Filmund\n\nBühnentochter einem Millionenpublikum bekannt.\n\nElf Jahre lang spielte sie meist die Tochter des großen Kölschen Volksschauspielers, so dass viele Zuschauer sie bis heute für die leibliche Tochter von Willy Millowitsch halten. Ende der 1960er Jahre begann Lotti Krekel eine erfolgreiche zweite Karriere ohne Millowitsch und wurde eher zufällig mit ihrem kölschen Hit „Mir schenke der Ahl e paar Blömcher“ zu einer erfolgreichen Sängerin. Daneben spielte sie in Fernsehfilmen und stand auf der Theater- oder Karnevalsbühne. Mit ihrem Mann Ernst Hilbich und ihrer jüngeren Halbschwester Hildegard Krekel, war\n\nsie in der Fernsehserie „Die Anrheiner“ zu sehen.", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
}

func TestUnmarshalBroadcastFromHTML_4(t *testing.T) {
	f, err := os.Open("testdata/2016-08-21T2305-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("wdr5")
	lang := "de"
	dtEnd, _ := time.Parse(time.RFC3339, "2016-08-22T00:00:00+02:00")
	bc0 := broadcast(r.Broadcast{
		BroadcastURL: r.BroadcastURL{
			TimeURL: r.TimeURL{
				Time:    time.Date(2016, time.August, 21, 23, 5, 0, 0, s.TimeZone),
				Source:  *r.MustParseURL("http://www.wdr.de/programmvorschau/wdr5/sendung/2016-08-21/41025663/der-wdr-5-literatursommer.html"),
				Station: r.Station(*s),
			},
			Title: "Der WDR 5 Literatursommer",
		},
		Language: &lang,
		DtEnd:    &dtEnd,
	})

	res, err := bc0.parseBroadcastFromHtmlReader(f, nil)
	assert.Equal(t, 1, len(res), "262")
	bc := res[0]

	assert.Nil(t, err, "ouch")
	assert.Equal(t, "wdr5", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Der WDR 5 Literatursommer", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.wdr.de/programmvorschau/wdr5/sendung/2016-08-21/41025663/der-wdr-5-literatursommer.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Michael Kumpfmüller gibt Erziehungsratschläge", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2016-08-21T23:05:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2016-08-22T00:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, "http://www1.wdr.de/radio/wdr5/sendungen/literatursommer/uebersicht-literatursommer102.html", bc.Subject.String(), "ouch: Subject")
	assert.Nil(t, bc.Modified, "ouch: Modified")
	assert.Equal(t, "WDR", *bc.Author, "ouch: Author")
	assert.Equal(t, "bis 24:00 Uhr\nWiederholung: 23.08. 03.05 Uhr\n\n„Die Erziehung des Mannes“ hat sich Michael Kumpfmüller in seinem jüngsten Roman zur Aufgabe gemacht. Am Beispiel von Georg, dem Protagonisten der Geschichte,\n\nerzählt er von den Fallstricken, mit denen Männer in Liebesdingen und im Ehealltag rechnen müssen.\n\nGeorgs Beziehungen gehen immer wieder in die Brüche, dann heiratet er Jule und bekommt mit ihr drei Kinder. Glücklich sind die beide trotzdem nicht. Aber wer trägt die\n\nSchuld an dem Problem? Die feministisch sozialisierte Frau, die ein neues männliches Rollenbild erwartet, und manchmal doch den alten Macho haben will? Der Vater, der seinen Kindern Zärtlichkeit und Nähe vorenthalten hat? Oder Georg selbst, der sich von den Ansprüchen von Frau und Kindern überfordert fühlt?\n\nMinutiös und durchaus komisch protokolliert Michael Kumpfmüller das Leben eines Durchschnittsmannes im 21. Jahrhundert. Immer auf der Suche nach einem Weg aus dem Dilemma von unerfüllbaren Erwartungen und festgefahrenen Verhaltensmustern.\n\nWDR 5 Literatursommer sendet Ausschnitte einer Veranstaltung der lit.COLOGNE 2016.", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
}
