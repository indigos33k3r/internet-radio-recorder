// Copyright (c) 2015-2017 Marcus Rohrmoser, http://purl.mro.name/recorder
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

package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"regexp"
	"strconv"

	"github.com/bogem/id3v2"
)

type tagError struct {
	reason string
}

func (e tagError) Error() string {
	return fmt.Sprintf("%s", e.reason)
}

func tagMp3File(mp3FilePath string, bc broadcast) error {
	m := regexp.MustCompile(`([^/]+)/(\d{4})/\d{2}/\d{2}/\d{4}(?:\s.*)?\.mp3$`).FindStringSubmatch(mp3FilePath)
	station := m[1]
	if "" == station {
		return tagError{reason: "Couldn't find station in mp3 file name '" + mp3FilePath + "'"}
	}

	tag, err := id3v2.Open(mp3FilePath, id3v2.Options{Parse: false})
	if nil != err {
		return err
	}
	defer tag.Close()

	tag.DeleteAllFrames()
	tag.SetVersion(4)
	tag.SetArtist("Station " + station)
	tag.SetTitle(bc.title)
	tag.SetAlbum(bc.title_series)
	tag.SetGenre("Radio")
	tag.SetYear(strconv.Itoa(bc.format_timestart.Year()))

	txt := bc.identifier + "\n"
	txt += bc.source.String() + "\n\n"
	if "" != bc.title_series {
		txt += bc.title_series + "\n\n"
	}
	if "" != bc.title_episode {
		txt += bc.title_episode + "\n\n"
	}
	txt += bc.description

	tag.AddCommentFrame(id3v2.CommentFrame{
		Encoding: id3v2.ENUTF8,
		Language: "deu", // validate language?
		Text:     txt,
	})

	tag.AddUnsynchronisedLyricsFrame(id3v2.UnsynchronisedLyricsFrame{
		Encoding: id3v2.ENUTF8,
		Language: "deu", // validate language?
		// ContentDescriptor: "Content descriptor",
		Lyrics: txt,
	})

	if "" != bc.image.String() {
		resp, err := http.Get(bc.image.String())
		if err != nil {
			return err
		}
		defer resp.Body.Close()
		b, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return err
		}
		tag.AddAttachedPicture(id3v2.PictureFrame{
			Encoding: id3v2.ENUTF8,
			MimeType: "image/jpeg",
			// Description: "Front cover",
			Picture:     b,
			PictureType: id3v2.PTFrontCover,
		})
	}

	return tag.Save()
}
