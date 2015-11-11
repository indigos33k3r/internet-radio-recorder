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
package dlf // import "purl.mro.name/recorder/radio/scrape/dlf"

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	//	r "purl.mro.name/recorder/radio/scrape"
)

var _ = fmt.Printf
var _ = os.Open
var _ = time.Sleep

func TestFactory(t *testing.T) {
	s := Station("dlf foo")
	assert.Nil(t, s, "ouch")
	s = Station("dlf")
	assert.NotNil(t, s, "ouch")
	assert.Equal(t, "Deutschlandfunk", s.Name, "ouch")
}

func TestTimeZone(t *testing.T) {
	s := Station("dlf")
	assert.Equal(t, "Europe/Berlin", s.TimeZone.String(), "ouch: TimeZone")
}

func TestDayURLForDate(t *testing.T) {
	s := Station("dlf")
	u, err := s.dayURLForDate(time.Date(2015, 11, 30, 5, 0, 0, 0, s.TimeZone))
	assert.Nil(t, err, "ouch: err")
	assert.Equal(t, "http://www.deutschlandfunk.de/programmvorschau.281.de.html?drbm:date=30.11.2015", u.Source.String(), "ouch")
	assert.Equal(t, "2015-11-30T00:00:00+01:00", u.Time.Format(time.RFC3339), "ouch")
}

func _TestParseDayURLs(t *testing.T) {
	f, err := os.Open("testdata/2015-11-11-dlf-programm.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")

	s := Station("dlf")
	tus, err := s.parseDayURLsReader(f)
	assert.Equal(t, 37, len(tus), "ouch")
}
