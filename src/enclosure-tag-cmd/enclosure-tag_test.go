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
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestIdentifierForMp3EnclosureFileName(t *testing.T) {
	assert.Equal(t, "", identifierForMp3EnclosureFileName(""), "ouch2")
	assert.Equal(t, "b2/2014/11/02/0605 radiowelt.mp3", identifierForMp3EnclosureFileName("foo/enclosures/b2/2014/11/02/0605 radiowelt.mp3"), "ouch2")
	assert.Equal(t, "b2/2014/11/02/0605.mp3", identifierForMp3EnclosureFileName("b2/2014/11/02/0605.mp3"), "ouch2")
}

func TestXmlBroadcastFileNameForMp3EnclosureFileName(t *testing.T) {
	assert.Equal(t, "", xmlBroadcastFileNameForMp3EnclosureFileName(""), "ouch2")
	assert.Equal(t, "", xmlBroadcastFileNameForMp3EnclosureFileName("b2/2014/11/02/0605 radioWelt.mp3"), "enclosures required")
	assert.Equal(t, "", xmlBroadcastFileNameForMp3EnclosureFileName("enclosures/b2/2014/11/02/0605 radiowelt.mp3"), "path prefix required")
	assert.Equal(t, "./stations/b2/2014/11/02/0605 radiowelt.xml", xmlBroadcastFileNameForMp3EnclosureFileName("./enclosures/b2/2014/11/02/0605 radiowelt.mp3"), "ouch2")
	assert.Equal(t, "foo/stations/b2/2014/11/02/0605 radiowelt.xml", xmlBroadcastFileNameForMp3EnclosureFileName("foo/enclosures/b2/2014/11/02/0605 radiowelt.mp3"), "ouch2")
}
