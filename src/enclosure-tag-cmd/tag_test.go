// Copyright (c) 2015-2017 Marcus Rohrmoser, https://github.com/mro/radio-pi
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

package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"

	"github.com/bogem/id3v2"

	"github.com/stretchr/testify/assert"
	"testing"
)

func copy(src, dst string) (int64, error) {
	src_file, err := os.Open(src)
	if err != nil {
		return 0, err
	}
	defer src_file.Close()

	src_file_stat, err := src_file.Stat()
	if err != nil {
		return 0, err
	}

	if !src_file_stat.Mode().IsRegular() {
		return 0, fmt.Errorf("%s is not a regular file", src)
	}

	dst_file, err := os.Create(dst)
	if err != nil {
		return 0, err
	}
	defer dst_file.Close()
	return io.Copy(dst_file, src_file)
}

func prepareMp3Copy() {
	os.Remove("testdata/tmp.mp3")
	_, err := copy("testdata/file.mp3", "testdata/tmp.mp3")
	if err != nil {
		panic("Ouch")
	}
}

func TestUnmodified(t *testing.T) {
	prepareMp3Copy()
	tag, err := id3v2.Open("testdata/tmp.mp3")
	assert.Nil(t, err, "")
	defer tag.Close()

	assert.Equal(t, "", tag.Artist(), "artist")
	assert.Equal(t, "", tag.Title(), "title")
	assert.Equal(t, "", tag.Album(), "album")
	assert.Equal(t, "", tag.Year(), "year")
}

func TestSetArtist(t *testing.T) {
	prepareMp3Copy()
	{
		// be paranoid an test initial emptyness
		tag, err := id3v2.Open("testdata/tmp.mp3")
		assert.Nil(t, err, "")
		assert.Equal(t, "", tag.Artist(), "artist")
		err = tag.Close()
		assert.Nil(t, err, "")
	}

	{
		tag, err := id3v2.Open("testdata/tmp.mp3")
		assert.Nil(t, err, "")
		tag.SetArtist("New 🚀 artist")
		err = tag.Save()
		assert.Nil(t, err, "")
		err = tag.Close()
		assert.Nil(t, err, "")
	}

	{
		tag, err := id3v2.Open("testdata/tmp.mp3")
		assert.Nil(t, err, "")
		assert.Equal(t, "New 🚀 artist", tag.Artist(), "artist")
		err = tag.Close()
		assert.Nil(t, err, "")
	}
}

func TestSetFull(t *testing.T) {
	prepareMp3Copy()
	{
		// be paranoid and test initial emptyness
		tag, err := id3v2.Open("testdata/tmp.mp3")
		assert.Nil(t, err, "")
		assert.Equal(t, "", tag.Artist(), "artist")
		assert.Equal(t, uint8(4), tag.Version(), "artist")
		err = tag.Close()
		assert.Nil(t, err, "")
	}

	{
		tag, err := id3v2.Open("testdata/tmp.mp3")
		assert.Nil(t, err, "")
		// tag.DeleteAllFrames()
		tag.SetVersion(4)
		tag.SetArtist("http://radiofabrik.at")
		tag.SetTitle("8 NACH 8 - DAS ENDE DER NACHT. Morgenmagazin mit Robert Schromm live aus dem Außenstudio Bad Reichenhall.")
		tag.SetAlbum("Album 🐳")
		tag.AddFrame(id3v2.V24CommonIDs["Composer"], id3v2.TextFrame{
			Encoding: id3v2.ENUTF8,
			Text:     "Composer 🌦",
		})

		tag.SetGenre("Radio")
		tag.SetYear("2016")

		tag.AddCommentFrame(id3v2.CommentFrame{
			Encoding: id3v2.ENUTF8,
			Language: "deu",
			// Description: "Description: Die dritte Person\nVon Gerhard Baumrucker\nMit Helmut Stange, Mathias Eysen, Christoph Lindert, Angelika Hartung-Atzorn, Christian Marschall und anderen\nRegie: Wolf Euba\nBR 1987\n\nInspektor Dorian von der Verkehrspolizei ist sich sicher: Die Staatsanwaltschaft wird das Verfahren gegen Kajetan Straub wegen fahrlässiger Tötung eines Fußgängers innerhalb der nächsten vier Wochen einstellen. Alkoholtest negativ. Zustand des Fahrzeugs einwandfrei. Nach den Erkenntnissen der Spurensicherung hat Kajetan Straub aus einer Geschwindigkeit von höchstens 30 km/h eine Vollbremsung bewirkt. Der Fall ist völlig klar!\n\nStraub ist sich da nicht so sicher: Kein Zweifel, dieser Watzlawek Wenzel ist ihm vor das Auto gelaufen. Doch als sich Straub nach und nach den Ablauf dieses schrecklichen Unfalls ins Gedächtnis ruft, glaubt er sich daran zu erinnern, dass er an jener verhängnisvollen Straßenkreuzung einen Schatten wahrgenommen hatte. Inspektor Dorian ist verblüfft, Kajetan Straub ist überzeugt: Das war kein Unfall! Der Schatten hinter dem Alleebaum muss das Opfer vor seinen PKW geschubst haben! Aber wer ist die dritte Person?\n\nGerhard Baumrucker, geb. 1929 in Prag, gest. 1992 in München, Autor und Übersetzer. Drehbücher, Prosa, Kriminalromane und Theatertexte. 1980/81 Edgar-Wallace-Preis für den Roman \"Die Weise von Liebe und Mord\". Weitere Kriminalromane u.a. \"Tödliches Rendezvous\" (1965), \"Schwabinger Nächte\" (1969), \"Drei Namen\" (1983). Weitere Hörspiele: \"Acapulco\" (WDR 1986), \"Nächstes Jahr in Acapulco\" (WDR 1986).",
			Text: "Text: Die dritte Person\nVon Gerhard Baumrucker\nMit Helmut Stange, Mathias Eysen, Christoph Lindert, Angelika Hartung-Atzorn, Christian Marschall und anderen\nRegie: Wolf Euba\nBR 1987\n\nInspektor Dorian von der Verkehrspolizei ist sich sicher: Die Staatsanwaltschaft wird das Verfahren gegen Kajetan Straub wegen fahrlässiger Tötung eines Fußgängers innerhalb der nächsten vier Wochen einstellen. Alkoholtest negativ. Zustand des Fahrzeugs einwandfrei. Nach den Erkenntnissen der Spurensicherung hat Kajetan Straub aus einer Geschwindigkeit von höchstens 30 km/h eine Vollbremsung bewirkt. Der Fall ist völlig klar!\n\nStraub ist sich da nicht so sicher: Kein Zweifel, dieser Watzlawek Wenzel ist ihm vor das Auto gelaufen. Doch als sich Straub nach und nach den Ablauf dieses schrecklichen Unfalls ins Gedächtnis ruft, glaubt er sich daran zu erinnern, dass er an jener verhängnisvollen Straßenkreuzung einen Schatten wahrgenommen hatte. Inspektor Dorian ist verblüfft, Kajetan Straub ist überzeugt: Das war kein Unfall! Der Schatten hinter dem Alleebaum muss das Opfer vor seinen PKW geschubst haben! Aber wer ist die dritte Person?\n\nGerhard Baumrucker, geb. 1929 in Prag, gest. 1992 in München, Autor und Übersetzer. Drehbücher, Prosa, Kriminalromane und Theatertexte. 1980/81 Edgar-Wallace-Preis für den Roman \"Die Weise von Liebe und Mord\". Weitere Kriminalromane u.a. \"Tödliches Rendezvous\" (1965), \"Schwabinger Nächte\" (1969), \"Drei Namen\" (1983). Weitere Hörspiele: \"Acapulco\" (WDR 1986), \"Nächstes Jahr in Acapulco\" (WDR 1986).",
		})

		tag.AddUnsynchronisedLyricsFrame(id3v2.UnsynchronisedLyricsFrame{
			Encoding: id3v2.ENUTF8,
			Language: "deu",
			// ContentDescriptor: "Content descriptor",
			Lyrics: "Die dritte Person\nVon Gerhard Baumrucker\nMit Helmut Stange, Mathias Eysen, Christoph Lindert, Angelika Hartung-Atzorn, Christian Marschall und anderen\nRegie: Wolf Euba\nBR 1987\n\nInspektor Dorian von der Verkehrspolizei ist sich sicher: Die Staatsanwaltschaft wird das Verfahren gegen Kajetan Straub wegen fahrlässiger Tötung eines Fußgängers innerhalb der nächsten vier Wochen einstellen. Alkoholtest negativ. Zustand des Fahrzeugs einwandfrei. Nach den Erkenntnissen der Spurensicherung hat Kajetan Straub aus einer Geschwindigkeit von höchstens 30 km/h eine Vollbremsung bewirkt. Der Fall ist völlig klar!\n\nStraub ist sich da nicht so sicher: Kein Zweifel, dieser Watzlawek Wenzel ist ihm vor das Auto gelaufen. Doch als sich Straub nach und nach den Ablauf dieses schrecklichen Unfalls ins Gedächtnis ruft, glaubt er sich daran zu erinnern, dass er an jener verhängnisvollen Straßenkreuzung einen Schatten wahrgenommen hatte. Inspektor Dorian ist verblüfft, Kajetan Straub ist überzeugt: Das war kein Unfall! Der Schatten hinter dem Alleebaum muss das Opfer vor seinen PKW geschubst haben! Aber wer ist die dritte Person?\n\nGerhard Baumrucker, geb. 1929 in Prag, gest. 1992 in München, Autor und Übersetzer. Drehbücher, Prosa, Kriminalromane und Theatertexte. 1980/81 Edgar-Wallace-Preis für den Roman \"Die Weise von Liebe und Mord\". Weitere Kriminalromane u.a. \"Tödliches Rendezvous\" (1965), \"Schwabinger Nächte\" (1969), \"Drei Namen\" (1983). Weitere Hörspiele: \"Acapulco\" (WDR 1986), \"Nächstes Jahr in Acapulco\" (WDR 1986).",
		})

		artwork, err := ioutil.ReadFile("testdata/image.jpg")
		assert.Nil(t, err, "")
		assert.Equal(t, int(110343), len(artwork), "size")
		tag.AddAttachedPicture(id3v2.PictureFrame{
			Encoding:    id3v2.ENUTF8,
			MimeType:    "image/jpeg",
			Description: "Front cover",
			Picture:     artwork,
			PictureType: id3v2.PTFrontCover,
		})

		err = tag.Save()
		assert.Nil(t, err, "")
		err = tag.Close()
		assert.Nil(t, err, "")
	}

	{
		tag, err := id3v2.Open("testdata/tmp.mp3")
		assert.Nil(t, err, "")
		assert.Equal(t, "http://radiofabrik.at", tag.Artist(), "artist")
		assert.Equal(t, "8 NACH 8 - DAS ENDE DER NACHT. Morgenmagazin mit Robert Schromm live aus dem Außenstudio Bad Reichenhall.", tag.Title(), "title")
		assert.Equal(t, "Album 🐳", tag.Album(), "album")
		assert.Equal(t, "Radio", tag.Genre(), "genre")
		assert.Equal(t, "2016", tag.Year(), "year")
		err = tag.Close()
		assert.Nil(t, err, "")
	}

	fi, _ := os.Stat("testdata/tmp.mp3")
	assert.Equal(t, int64(4671582), fi.Size(), "size")
}
