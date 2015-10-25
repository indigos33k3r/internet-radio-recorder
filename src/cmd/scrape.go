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

package main

import (
	"fmt"

	"purl.mro.name/recorder/radio/scrape"
)

func main() {
	station := scrape.StationBR("b2")

	if false {
		urls,_ := scrape.ParseDayURLs(station)
		for _,d := range urls {
			fmt.Printf("%s\n", d.String())
		}
	} else if false {
		urls,_ := scrape.ParseBroadcastURLs(station, station.ProgramURL)
		for _,d := range urls {
			fmt.Printf("%s\n", d.String())
		}
	} else {
		c := make(chan scrape.Broadcast)
		scrape.ScrapeIncremental(c)
		close(c)
	}
}
