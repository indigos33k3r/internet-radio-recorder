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

package main

import (
	"fmt"
	"os"
	"sync"
	"time"

	"purl.mro.name/recorder/radio/scrape"
	"purl.mro.name/recorder/radio/scrape/b3"
	"purl.mro.name/recorder/radio/scrape/b4"
	"purl.mro.name/recorder/radio/scrape/br"
	"purl.mro.name/recorder/radio/scrape/dlf"
	"purl.mro.name/recorder/radio/scrape/m945"
	"purl.mro.name/recorder/radio/scrape/radiofabrik"
	"purl.mro.name/recorder/radio/scrape/wdr"
)

func main() {
	results := make(chan scrape.Broadcaster) // sequential
	jobs := make(chan scrape.Scraper, 15)    // concurrent
	defer close(results)
	defer close(jobs)

	var wg_jobs sync.WaitGroup
	var wg_results sync.WaitGroup

	{
		// seed all the radio stations to scrape
		for _, s := range []string{"b1", "b2", "b5", "b+", "brheimat", "puls"} {
			wg_jobs.Add(1)
			jobs <- br.Station(s)
		}
		wg_jobs.Add(1)
		jobs <- b3.Station("b3")
		wg_jobs.Add(1)
		jobs <- b4.Station("b4")

		wg_jobs.Add(1)
		jobs <- radiofabrik.Station("radiofabrik")
		wg_jobs.Add(1)
		jobs <- m945.Station("m945")
		wg_jobs.Add(1)
		jobs <- dlf.Station("dlf")
		wg_jobs.Add(1)
		jobs <- wdr.Station("wdr5")
	}

	nows := scrape.IncrementalNows(time.Now())

	// scrape and write concurrently

	// scraper loop
	go func() {
		for jobb := range jobs {
			job := jobb
			go func() {
				defer wg_jobs.Done()
				// fmt.Fprintf(os.Stderr, "jobs process %p %s\n", job, job)
				scrapers, bcs, err := job.Scrape()
				if nil != err {
					fmt.Fprintf(os.Stderr, "error %s %s\n", job, err)
				}
				for _, s := range scrapers {
					if s.Matches(nows) {
						wg_jobs.Add(1)
						// fmt.Fprintf(os.Stderr, "jobs queue   %p %s\n", s, s)
						jobs <- s
					}
				}
				for _, b := range bcs {
					wg_results.Add(1)
					results <- b
				}
			}()
		}
	}()

	// write loop
	go func() {
		for bc := range results {
			defer wg_results.Done()
			bc.WriteAsLuaTable(os.Stdout)
		}
	}()

	wg_jobs.Wait()
	wg_results.Wait()
}
