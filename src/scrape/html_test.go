// Copyright (c) 2016-2016 Marcus Rohrmoser, http://purl.mro.name/recorder
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
//
// import "purl.mro.name/recorder/radio/scrape"
//
package scrape

import (
	"os"
	"testing"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"

	"github.com/stretchr/testify/assert"
	"github.com/yhat/scrape"
)

func TestTextWithBrFromNodeSet_001(t *testing.T) {
	f, err := os.Open("testdata/TextWithBrFromNodeSet_001.html")
	assert.NotNil(t, f, "ouch")
	assert.Nil(t, err, "ouch")
	root, err := html.Parse(f)
	assert.NotNil(t, root, "ouch")
	assert.Nil(t, err, "ouch")
	nodes := scrape.FindAll(root, func(n *html.Node) bool { return atom.Div == n.DataAtom })

	txt := TextWithBrFromNodeSet(nodes)
	assert.Equal(t, "foo\n\nbar\nfoo\n\nbar", txt, "ouch")

}
