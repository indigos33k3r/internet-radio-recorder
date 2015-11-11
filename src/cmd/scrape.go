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
	"purl.mro.name/recorder/radio/scrape/dlf"
	"purl.mro.name/recorder/radio/scrape/m945"
)

func main() {
	results := make(chan scrape.Broadcaster)
	jobs := make(chan scrape.Scraper, 1)

	var wg_scrapers sync.WaitGroup

	wg_scrapers.Add(1)
	go func() {
		defer wg_scrapers.Done()
		jobs <- dlf.Station("m945")
		jobs <- dlf.Station("dlf")
		jobs <- br.Station("b1")
		jobs <- br.Station("b2")
		jobs <- br.Station("b3")
		jobs <- br.Station("b4")
		jobs <- br.Station("b5")
		jobs <- br.Station("b+")
		jobs <- br.Station("brheimat")
		jobs <- br.Station("puls")
	}()

	now := time.Now()

	incremental_nows := scrape.IncrementalNows(&now)

	// Scraper loop
	go func() {
		for job := range jobs {
			for _, n := range incremental_nows {
				if job.Matches(&n) {
					goto DoScrape
				}
			}
			continue
		DoScrape:
			wg_scrapers.Add(1)
			go func() {
				defer wg_scrapers.Done()
				err := job.Scrape(jobs, results)
				if nil != err {
					fmt.Fprintf(os.Stderr, "error %s %s\n", job, err)
				}
			}()
		}
	}()

	var wg_write sync.WaitGroup
	// Broadcaster loop
	go func() {
		wg_write.Add(1)
		defer wg_write.Done()
		for bc := range results {
			// bcc := bc.Broadcast()
			// fmt.Fprintf(os.Stderr, "done     %s - %s '%s' %s\n", bcc.Time, bcc.DtEnd, bcc.Title, bcc.Source.String())
			bc.WriteAsLuaTable(os.Stdout)
		}
	}()

	time.Sleep(time.Millisecond)
	wg_scrapers.Wait()
	close(jobs)
	close(results)
	wg_write.Wait()
	time.Sleep(10 * time.Second)
}
