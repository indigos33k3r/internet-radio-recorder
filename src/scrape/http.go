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

// Generic stuff useful for scraping radio broadcast station program
// websites.
//
// Most important are the two interfaces 'Scraper' and 'Broadcaster'.
//
// import "purl.mro.name/recorder/radio/scrape"
//
package scrape

import (
	"compress/gzip"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
)

func contains(haystack []string, needle string) bool {
	for _, s := range haystack {
		if needle == s {
			return true
		}
	}
	return false
}

/// One to fetch them all (except dlf with it's POST requests).
func HttpGetBody(url url.URL) (io.ReadCloser, error) {
	client := &http.Client{}
	req, _ := http.NewRequest("GET", url.String(), nil)
	req.Header.Set("Accept-Encoding", "gzip, deflate")
	resp, err := client.Do(req)
	if nil == resp {
		return nil, err
	}
	for _, cl := range resp.Header["Content-Length"] {
		fmt.Fprintf(os.Stderr, "loaded %s B\n", cl)
	}
	encs := resp.Header["Content-Encoding"]
	switch {
	case contains(encs, "gzip"), contains(encs, "deflate"):
		ret, err := gzip.NewReader(resp.Body)
		return ret, err
	default:
		fmt.Fprintf(os.Stderr, "Strange compression: %s\n", encs)
	}
	return resp.Body, err
}

/// Sadly doesn't make things really simpler
func GenericParseBroadcastFromURL(url url.URL, callback func(r io.Reader) ([]Broadcast, error)) (bc []Broadcast, err error) {
	bo, err := HttpGetBody(url)
	if nil == bo {
		return nil, err
	}
	defer bo.Close()
	return callback(bo)
}
