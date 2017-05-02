// Copyright (c) 2016-2017 Marcus Rohrmoser, http://purl.mro.name/recorder
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

package scrape

import (
	"regexp"
	"strings"
	"unicode"

	"github.com/yhat/scrape"
	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

const lineFeedMarker = "55855D6B-4E49-4B83-BE50-082ECB380AB1"

func TextWithBrFromNodeSet(nodes []*html.Node) string {
	parts := make([]string, len(nodes))
	for i, node := range nodes {
		for _, tag := range []atom.Atom{atom.Br, atom.Tr} {
			for _, n := range scrape.FindAll(node, func(n *html.Node) bool { return tag == n.DataAtom }) {
				lfn := html.Node{Type: html.TextNode, Data: lineFeedMarker}
				n.Parent.InsertBefore(&lfn, n.NextSibling)
			}
		}
		for _, tag := range []atom.Atom{atom.P, atom.Div} {
			for _, n := range scrape.FindAll(node, func(n *html.Node) bool { return tag == n.DataAtom }) {
				lfn := html.Node{Type: html.TextNode, Data: lineFeedMarker + lineFeedMarker}
				n.Parent.InsertBefore(&lfn, n.NextSibling)
			}
		}
		tmp := []string{}
		for _, n := range scrape.FindAll(node, func(n *html.Node) bool { return html.TextNode == n.Type }) {
			tmp = append(tmp, n.Data)
		}
		parts[i] = strings.Join(tmp, "")
	}
	ret := strings.Join(parts, lineFeedMarker+lineFeedMarker)
	ret = NormaliseWhiteSpace(ret)
	ret = strings.Replace(ret, lineFeedMarker, "\n", -1)
	re := regexp.MustCompile("[ ]*(\\s)[ ]*") // collapse whitespace, keep \n
	ret = re.ReplaceAllString(ret, "$1")      // collapse whitespace (not the \n\n however)
	{
		re := regexp.MustCompile("\\s*\\n\\s*\\n\\s*") // collapse linefeeds
		ret = re.ReplaceAllString(ret, "\n\n")
	}
	return strings.TrimSpace(ret)
}

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

func NormaliseWhiteSpace(s string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsSpace(r) {
			return rune(32)
		}
		return r
	}, s)
}
