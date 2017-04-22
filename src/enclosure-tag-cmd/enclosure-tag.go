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
	// "log" // log.Fatal
	"os"
	"path/filepath"
	"regexp"
)

func main() {
	if 1 >= len(os.Args) || "-?" == os.Args[1] || "--help" == os.Args[1] {
		commandHelp()
		return
	}

	for _, mp3FileName := range os.Args[1:] {
		fmt.Fprintf(os.Stderr, "tagging %s\n", mp3FileName)
		ap, err := filepath.Abs(mp3FileName)
		if nil != err {
			fmt.Fprintf(os.Stderr, "error %s\n", err)
			continue
		}

		bc, err := broadcastFromXmlFileName(xmlBroadcastFileNameForMp3EnclosureFileName(ap))
		if nil != err {
			fmt.Fprintf(os.Stderr, "error %s\n", err)
			continue
		}

		err = tagMp3File(ap, bc)
		if nil != err {
			fmt.Fprintf(os.Stderr, "error %s\n", err)
			continue
		}
	}
}

func commandHelp() {
	program := os.Args[0]
	fmt.Printf("Usage: %s enclosure0.mp3 enclosure1.mp3 enclosure2.mp3\n", program)
	fmt.Printf("\n")
	fmt.Printf("tags the given enclosures with meta data from it's broadcast file (xml).\n")
}

func identifierForMp3EnclosureFileName(mp3FileName string) string {
	rx := regexp.MustCompile("[^/]+/\\d{4}/\\d{2}/\\d{2}/\\d{4}(?: .+)?\\.mp3$")
	return rx.FindString(mp3FileName)
}

func xmlBroadcastFileNameForMp3EnclosureFileName(mp3FileName string) string {
	rx := regexp.MustCompile("^(.*)/enclosures/([^/]+/\\d{4}/\\d{2}/\\d{2}/\\d{4}(?: .+)?)\\.mp3$")
	ret := rx.ReplaceAllString(mp3FileName, "$1/stations/$2.xml")
	if ret == mp3FileName {
		return ""
	}
	return ret
}
