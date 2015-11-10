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
	"os"
	"sync"
	"time"

	"purl.mro.name/recorder/radio/scrape"
	"purl.mro.name/recorder/radio/scrape/br"
)

func main() {
	broadcasts := make(chan scrape.Broadcaster)
	scrapers := make(chan scrape.Scraper, 1)

	now := time.Now()

	var wg_scrapers sync.WaitGroup

	wg_scrapers.Add(1)
	go func() {
		defer wg_scrapers.Done()
		scrapers <- br.Station("b1")
		scrapers <- br.Station("b2")
		scrapers <- br.Station("b3")
		scrapers <- br.Station("b4")
		scrapers <- br.Station("b5")
		scrapers <- br.Station("b+")
		scrapers <- br.Station("brheimat")
		scrapers <- br.Station("puls")
	}()

	// Scraper loop
	go func() {
		for job := range scrapers {
			if !job.Matches(&now) {
				continue
			}
			wg_scrapers.Add(1)
			go func() {
				defer wg_scrapers.Done()
				err := job.Scrape(broadcasts, scrapers, &now)
				if nil != err {
					fmt.Fprintf(os.Stderr, "error %s %s\n", job, err)
				}
			}()
		}
	}()

	var wg_write sync.WaitGroup
	// Broadcaster loop
	go func() {
		for bc := range broadcasts {
			wg_write.Add(1)
			go func() {
				defer wg_write.Done()
				bcc := bc.Broadcast()
				fmt.Fprintf(os.Stderr, "done     %s - %s '%s' %s\n", bcc.Time, bcc.DtEnd, bcc.Title, bcc.Source.String())
			}()
		}
	}()

	time.Sleep(time.Millisecond)
	wg_scrapers.Wait()
	close(scrapers)
	wg_write.Wait()
	time.Sleep(10 * time.Second)
	close(broadcasts)
}
