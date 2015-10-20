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

package scrape // import "purl.mro.name/recorder/radio/scrape"

import (
	"net/http"
	"net/url"
	"regexp"
	"time"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

var (
	dayRegExp *regexp.Regexp = regexp.MustCompile("^/radio/.+~_date-([0-9]{4}-[0-9]{2}-[0-9]{2})_-.+$")
)

func newTimeURL(programURL url.URL, relUrl string) *TimeURL {
	programURL.Path = relUrl

	m := dayRegExp.FindStringSubmatch(relUrl)
	if nil == m {
		return nil
	}
	dayStr := m[1]

	day, err := time.ParseInLocation("2006-01-02", dayStr, localLoc)
	if nil != err {
		panic(err)
	}

	return &TimeURL{Time: day, Source: programURL}
}

func ParseDayURLs(programURL *url.URL, c chan TimeURL) {
	defer close(c)
	resp, err := http.Get(programURL.String())
	if nil != err {
		panic(err)
	}
	root, err := html.Parse(resp.Body)
	if nil != err {
		panic(err)
	}
	i := 0
	for _, article := range scrape.FindAll(root, func(n *html.Node) bool { return atom.A == n.DataAtom }) {
		d := newTimeURL(*programURL, scrape.Attr(article, "href"))
		if nil != d {
			// use only every 3rd day schedule url because each one contains 3 days
			i += 1
			if 2 != i%3 {
				continue
			}
			c <- *d
		}
	}
}
