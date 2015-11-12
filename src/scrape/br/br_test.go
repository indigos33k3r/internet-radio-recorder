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
package br // import "purl.mro.name/recorder/radio/scrape/br"

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	r "purl.mro.name/recorder/radio/scrape"
)

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

func TestTimeZone(t *testing.T) {
	b2 := Station("b2")
	assert.Equal(t, "Europe/Berlin", b2.TimeZone.String(), "foo")
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

func TestParseCalendarForDayURLs(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21-b2-program.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	b2 := Station("b2")
	tus, err := b2.parseDayURLsReader(f)
	assert.Equal(t, 37, len(tus), "ouch")
	assert.Equal(t, "b2", tus[0].TimeURL.Station.Identifier, "ouch: ")
}

func TestParseScheduleForBroadcasts(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21-b2-program.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("b2")
	t0 := r.TimeURL{
		Time:    time.Date(2015, time.October, 21, 5, 0, 0, 0, localLoc),
		Source:  *r.MustParseURL("http://www.br.de/radio/bayern2/programmkalender/programmfahne102~_date-2015-10-21_-5ddeec3fc12bdd255a6c45c650f068b54f7b010b.html"),
		Station: s.Station,
	}
	a, err := s.parseBroadcastURLsReader(&t0.Source, f)
	assert.Equal(t, 129, len(a), "ouch: len")
	assert.Equal(t, "b2", a[0].TimeURL.Station.Identifier, "ouch: ")
	assert.Equal(t, "2015-10-20T05:00:00+02:00", a[0].Time.Format(time.RFC3339), "ouch: ")
	assert.Equal(t, "2015-10-23T04:58:00+02:00", a[128].Time.Format(time.RFC3339), "ouch: ")
}

func TestParseBroadcast_0(t *testing.T) {
	{
		t0, _ := time.Parse(time.RFC3339, "2015-10-22T00:06:13+02:00")
		assert.Equal(t, "2015-10-22T00:06:13+02:00", t0.Format(time.RFC3339), "oha")
	}
	f, err := os.Open("testdata/2015-10-21T0012-b2-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("b2")
	t0 := r.BroadcastURL{
		TimeURL: r.TimeURL{
			Time:    time.Date(2015, time.October, 21, 0, 12, 0, 0, localLoc),
			Source:  *r.MustParseURL("http://www.br.de/radio/bayern2/programmkalender/ausstrahlung-472548.html"),
			Station: s.Station,
		},
		Title: "Concerto bavarese",
	}

	// http://rec.mro.name/stations/b2/2015/10/21/0012%20Concerto%20bavarese
	bc, err := s.parseBroadcastReader(&t0.TimeURL.Source, f)
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "b2", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Concerto bavarese", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.br.de/radio/bayern2/programmkalender/ausstrahlung-472548.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, t0.Title, bc.Title, "ouch: Title")
	assert.Equal(t, "Aus dem Studio Franken:", *bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Fränkische Komponisten", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-10-21T00:12:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-10-21T02:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, "http://www.br.de/radio/bayern2/musik/concerto-bavarese/index.html", bc.Subject.String(), "ouch: Subject")
	assert.Equal(t, "2015-10-22T00:06:13+02:00", bc.Modified.Format(time.RFC3339), "ouch: Modified")
	assert.Equal(t, "Bayerischer Rundfunk", *bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "Franz Schillinger: \"Insisting Voices II\"; \"Veränderliche Langsamkeiten III\" (Wilfried Krüger, Horn; Heinrich Rauh, Violine); Stefan David Hummel: \"In one's heart of hearts\" (Stefan Teschner, Violine; Klaus Jäckle, Gitarre; Sven Forker, Schlagzeug); Matthias Schmitt: Sechs Miniaturen (Katarzyna Mycka, Marimbaphon); Stefan Hippe: \"Annacamento\" (ars nova ensemble nürnberg: Werner Heider); Ludger Hofmann-Engl: \"Abstract I\" (Wolfgang Pessler, Fagott; Sebastian Rocholl, Viola; Ralf Waldner, Cembalo); Ulrich Schultheiß: \"Bubbles\" (Stefan Barcsay, Gitarre)", *bc.Description, "ouch: Description")
	assert.NotNil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.br.de/layout/img/programmfahne/concerto-bavarese112~_v-img__16__9__m_-4423061158a17f4152aef84861ed0243214ae6e7.jpg?version=40aa3", bc.Image.String(), "ouch: Image")
}

func TestParseBroadcast_1(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21T1005-b2-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("b2")
	t0 := r.BroadcastURL{
		TimeURL: r.TimeURL{
			Time:    time.Date(2015, time.October, 21, 10, 5, 0, 0, localLoc),
			Source:  *r.MustParseURL("http://www.br.de/radio/bayern2/programmkalender/ausstrahlung-472576.html"),
			Station: s.Station,
		},
		Title: "Notizbuch",
	}

	// http://rec.mro.name/stations/b2/2015/10/21/1005%20Notizbuch
	bc, err := s.parseBroadcastReader(&t0.TimeURL.Source, f)
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "b2", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Notizbuch", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.br.de/radio/bayern2/programmkalender/ausstrahlung-472576.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, t0.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Kann das Warenhaus sich neu erfinden?", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-10-21T10:05:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-10-21T12:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, "http://www.br.de/radio/bayern2/gesellschaft/notizbuch/index.html", bc.Subject.String(), "ouch: Subject")
	assert.Equal(t, "2015-10-22T00:06:25+02:00", bc.Modified.Format(time.RFC3339), "ouch: Modified")
	assert.Equal(t, "Bayerischer Rundfunk", *bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "Niedrigzinsen:\nPfandhäuser haben Hochkonjuktur trotz Niedrigzinsen /\nWo legen Sie ihr Geld an und wieviel Zinsen bekommen Sie dafür? /\nEin bisschen Risiko muss sein? Wie Anbieter für Produkte werben /\n\nNah dran:\n\"Alles unter einem Dach\" - Kann das Warenhaus sich neu erfinden? /\n\nMünzen:\nBrauchen wir noch Ein- und Zwei-Cent-Münzen? /\nSammler unter sich - Zu Besuch auf der Numismatika, Berlin /\nGehortet - Was tun mit dem Rotgeld, das Zuhause liegt? /\n\nNotizbuch Service:\nWenn der Postmann gar nicht klingelt -\nWas tun mit Briefen, die falsch zugestellt wurden? /\n\nLangsam Essen für Kinder:\nSlow Food stellt ein Kochbuch für Kinder vor - Kann sich das jeder leisten? /\n\nKurz vor 12:\nGlosse: Konsumverzicht\n\nModeration: Christine Bergmann\n11.00 Nachrichten, Wetter\n11.56 Werbung\nAusgewählte Beiträge als Podcast verfügbar\n\nNah dran: \"Alles unter einem Dach\" - Kann das Warenhaus sich neu erfinden?\n\nKarstadt, Wertheim, Tietz - diese Warenhäuser setzten einst unsere Großmütter in helle Erregung. Vom \"Paradies der Damen\" war die Rede - aber natürlich kamen auch die Herren auf ihre Kosten. In den für damalige Zeiten riesigen Verkaufsflächen gab es, wie ein Werbeslogan versprach \"tausendfach alles unter einem Dach\". Doch dann kamen die Möbelhäuser, die Elektronikfachmärkte, die Supermärkte im Gewerbegebiet und die riesigen Einkaufszentren. Nicht zuletzt macht das Internet dem stationären Einzelhandel Konkurrenz. Die Kunden kaufen überall - nur nicht mehr im Warenhaus. Hertie ist pleite, Karstadt kämpft ums Überleben. Kaufhof wurde jüngst an eine kanadische Kette verkauft. Hat das zentrumsnahe Kaufhaus heute noch eine Chance? Wie können Warenhäuser wieder mehr Kunden anlocken? Unterschiedliche Konzepte werden ausprobiert - Ralf Schmidberger hat sie unter die Lupe genommen.", *bc.Description, "ouch: Description")
	assert.NotNil(t, bc.Image.String(), "ouch: Image")
	assert.Equal(t, "http://www.br.de/layout/img/programmfahne/sendungsbild128~_v-img__16__9__m_-4423061158a17f4152aef84861ed0243214ae6e7.jpg?version=d2b9d", bc.Image.String(), "ouch: Image")
}

func TestParseBroadcastUntilMidnight(t *testing.T) {
	f, err := os.Open("testdata/2015-10-21T2305-b2-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("b2")
	t0 := r.BroadcastURL{
		TimeURL: r.TimeURL{
			Time:    time.Date(2015, time.October, 21, 23, 5, 0, 0, localLoc),
			Source:  *r.MustParseURL("http://www.br.de/radio/bayern2/programmkalender/ausstrahlung-472628.html"),
			Station: s.Station,
		},
		Title: "Nachtmix",
	}

	// http://rec.mro.name/stations/b2/2015/10/21/2305%20Nachtmix
	bc, err := s.parseBroadcastReader(&t0.Source, f)
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "b2", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Nachtmix", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.br.de/radio/bayern2/programmkalender/ausstrahlung-472628.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, t0.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Die Akustik-Avantgarde", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-10-21T23:05:00+02:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-10-22T00:00:00+02:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, "http://www.br.de/radio/bayern2/musik/nachtmix/index.html", bc.Subject.String(), "ouch: Subject")
	assert.Equal(t, "2015-10-20T13:05:12+02:00", bc.Modified.Format(time.RFC3339), "ouch: Modified")
	assert.Equal(t, "Bayerischer Rundfunk", *bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "Die Akustik-Avantgarde\nMusik von Joanna Newsom, Andrew Bird und Devendra Banhart\nMit Michael Bartlewski\n\nJoanna Newsom ist ziemlich einzigartig: Ihre Stimme ist piepsig, ihre Songs können gerne mal acht Minuten sein und dann spielt sie auch noch Harfe. Nicht die besten Voraussetzungen für eine Pop-Karriere. Joanna Newsom hat es trotzdem geschafft - wir blicken auf ihre einmalige Geschichte zurück. Die Harfe bezeichnet Joanna Newsom als Erweiterung ihres Körpers, im Nachtmix gibt es noch mehr Musik von Virtuosen, die die Pop-Welt mit ihren kauzigen, besonders instrumentierten Songs bereichern. Andrew Bird ist der loopende Violinist, Devendra Banhart bleibt wohl immer ein Hippie, und für CocoRosie kann auch auf dem neuen Album alles ein Instrument sein. Dazu: Alela Diane mit klassischen Folk-Klängen und Helado Negro verzaubert mit Zeitlupen-Disco.", *bc.Description, "ouch: Description")
	assert.NotNil(t, bc.Image.String(), "ouch: Image")
	assert.Equal(t, "http://www.br.de/layout/img/programmfahne/nachtmix112~_v-img__16__9__m_-4423061158a17f4152aef84861ed0243214ae6e7.jpg?version=1beb6", bc.Image.String(), "ouch: Image")
}

func TestParseBroadcastWithImage(t *testing.T) {
	f, err := os.Open("testdata/2015-11-11T2305-b4-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("b4")
	t0 := r.BroadcastURL{
		TimeURL: r.TimeURL{
			Time:    time.Date(2015, time.November, 11, 23, 5, 0, 0, localLoc),
			Source:  *r.MustParseURL("http://www.br.de/radio/br-klassik/programmkalender/ausstrahlung-493432.html"),
			Station: s.Station,
		},
		Title: "Jazztime",
	}

	// http://rec.mro.name/stations/b4/2015/11/11/2305%20Jazztime
	bc, err := s.parseBroadcastReader(&t0.Source, f)
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "b4", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Jazztime", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.br.de/radio/br-klassik/programmkalender/ausstrahlung-493432.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, t0.Title, bc.Title, "ouch: Title")
	assert.Equal(t, "Aus dem Studio Franken:", *bc.TitleSeries, "ouch: TitleSeries")
	assert.Equal(t, "Jazz aus Nürnberg: Live-Mitschnitte", *bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-11-11T23:05:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-11-12T00:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 3300*time.Second, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.Equal(t, "http://www.br.de/radio/br-klassik/sendungen/jazztime/index.html", bc.Subject.String(), "ouch: Subject")
	assert.Equal(t, "2015-11-11T09:15:08+01:00", bc.Modified.Format(time.RFC3339), "ouch: Modified")
	assert.Equal(t, "Bayerischer Rundfunk", *bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "Philipp Gropper´s Philm im Jazzstudio Nürnberg\nMit Philipp Gropper (Tenorsaxophon), Elias Stemeseder (Piano), Andreas Lang (Bass) und Oliver Steidle (Schlagzeug)\nAufnahme vom 2. Oktober 2015\nModeration und Auswahl: Beate Sampson\n\nPhilipp Gropper´s Philm: „Madman of Naranam“ (Philipp Gropper)\nPhilipp Gropper´s Philm: „ZE“ (Philipp Gropper)\nPhilipp Gropper´s Philm: „Licht“ (Philipp Gropper)\nPhilipp Gropper´s Philm: „Synthesizer/ Für die 68er“ (Philipp Gropper)\n\n\"Je länger ich Musik mache, desto wichtiger ist mir und desto klarer nehme ich wahr, was Musik, was eine Band transportiert, welche Botschaft von Ihr ausgeht. Diese durch die transzendierende Qualität von Musik erfahrbare Essenz ist, worum es geht und sie ist absolut unabhängig von Stilistik oder Besetzung. Reine Virtuosität, reine intellektuelle Höhenflüge oder die allgegenwärtige Weichgespültheit langweilen mich, es geht mir um Direktheit und Aura. Ich bin der Tradition sehr verbunden, versuche aber ständig deren Lebendigkeit und Frische, die jeweils nur im zeitlichen Kontext entstehen konnte und den alten Meistern gleichzeitig ihre Zeitlosigkeit sicherte, zu verstehen und weiterzutragen.\" So beschreibt der Berliner Saxophonist Philipp Gropper sein künstlerisches Selbstverständnis. Mit seinem 2011 gegründeten Quartett PHILM hat er es am 2. Oktober 2015 im Nürnberger Jazzstudio in Musik zum Ausdruck gebracht. Sie ist heute in unserem Mitschnitt des Konzertabends zu hören.", *bc.Description, "ouch: Description")
	assert.NotNil(t, bc.Image, "ouch: Image")
	assert.Equal(t, "http://www.br.de/radio/br-klassik/sendungen/jazztime/gropper-100~_v-img__16__9__m_-4423061158a17f4152aef84861ed0243214ae6e7.jpg?version=230c6", bc.Image.String(), "ouch: Image")
	assert.Nil(t, bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")
}

func TestParseBroadcast23h55min(t *testing.T) {
	f, err := os.Open("testdata/2015-11-15T0005-b+-sendung.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("b+")
	t0 := r.BroadcastURL{
		TimeURL: r.TimeURL{
			Time:    time.Date(2015, time.November, 11, 15, 5, 0, 0, localLoc),
			Source:  *r.MustParseURL("http://www.br.de/radio/bayern-plus/programmkalender/ausstrahlung-497666.html"),
			Station: s.Station,
		},
		Title: "Bayern plus - Meine Schlager hören",
	}

	// http://rec.mro.name/stations/b%2b/2015/11/15/0005%20Bayern%20plus%20-%20Meine%20Schlager%20h%C3%B6ren
	bc, err := s.parseBroadcastReader(&t0.Source, f)
	assert.Nil(t, err, "ouch")
	assert.Equal(t, "b+", bc.Station.Identifier, "ouch: Station.Identifier")
	assert.Equal(t, "Bayern plus - Meine Schlager hören", bc.Title, "ouch: Title")
	assert.Equal(t, "http://www.br.de/radio/bayern-plus/programmkalender/ausstrahlung-497666.html", bc.Source.String(), "ouch: Source")
	assert.NotNil(t, bc.Language, "ouch: Language")
	assert.Equal(t, "de", *bc.Language, "ouch: Language")
	assert.Equal(t, t0.Title, bc.Title, "ouch: Title")
	assert.Nil(t, bc.TitleSeries, "ouch: TitleSeries")
	assert.Nil(t, bc.TitleEpisode, "ouch: TitleEpisode")
	assert.Equal(t, "2015-11-15T00:05:00+01:00", bc.Time.Format(time.RFC3339), "ouch: Time")
	assert.Equal(t, "2015-11-16T00:00:00+01:00", bc.DtEnd.Format(time.RFC3339), "ouch: DtEnd")
	assert.Equal(t, 1435*time.Minute, bc.DtEnd.Sub(bc.Time), "ouch: Duration")
	assert.Nil(t, bc.Subject, "ouch: Subject")
	assert.Equal(t, "2015-10-29T01:25:04+01:00", bc.Modified.Format(time.RFC3339), "ouch: Modified")
	assert.Equal(t, "Bayerischer Rundfunk", *bc.Author, "ouch: Author")
	assert.NotNil(t, bc.Description, "ouch: Description")
	assert.Equal(t, "Jeweils zur vollen Stunde\nNachrichten, Wetter, Verkehr", *bc.Description, "ouch: Description")
	assert.Nil(t, bc.Image, "ouch: Image")
	assert.Nil(t, bc.Publisher, "Publisher")
	assert.Nil(t, bc.Creator, "Creator")
	assert.Nil(t, bc.Copyright, "Copyright")
}
