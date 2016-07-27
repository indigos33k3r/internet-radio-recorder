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

// HTML helpers.
//
// import "purl.mro.name/recorder/radio/scrape"
//
package scrape

import (
	"strings"
	"unicode"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

func TextChildrenNoClimb(node *html.Node) string {
	ret := []string{}
	for n := node.FirstChild; nil != n; n = n.NextSibling {
		if html.TextNode != n.Type {
			continue
		}
		ret = append(ret, strings.TrimSpace(n.Data))
	}
	return strings.Join(ret, "")
}

func TextWithBr(node *html.Node) string {
	nodes := scrape.FindAll(node, func(n *html.Node) bool { return n.Type == html.TextNode || atom.Br == n.DataAtom })
	parts := make([]string, len(nodes))
	for i, n := range nodes {
		if atom.Br == n.DataAtom {
			parts[i] = "\n"
		} else {
			parts[i] = NormaliseWhiteSpace(n.Data)
		}
	}
	return strings.Join(parts, "")
}

func TextsWithBr(nodes []*html.Node) (ret []string) {
	ret = make([]string, len(nodes))
	for i, p := range nodes {
		// BUG(mro): so where goes this?
		ret[i] = TextWithBr(p)
	}
	return
}

func NormaliseWhiteSpace(s string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsSpace(r) {
			return rune(32)
		} else {
			return r
		}
	}, s)
}
