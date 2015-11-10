#!/bin/sh
# https://golang.org/doc/install/source#environment
#

cd "$(dirname "$0")"

VERSION=0.0.1

rm "scrape"-*-"$VERSION" 2>/dev/null

cd ../scrape
go get github.com/yhat/scrape
go get github.com/stretchr/testify
go fmt
cd - && cd ../scrape/br
go fmt
go test
cd -
go fmt

# http://dave.cheney.net/2015/08/22/cross-compilation-with-go-1-5
# env GOOS=linux GOARCH=arm GOARM=6 go build -o scrape-linux-arm-$VERSION
env GOOS=linux GOARCH=amd64 go build -o scrape-linux-amd64-$VERSION
# env GOOS=darwin GOARCH=amd64 go build -o scrape-darwin-amd64-$VERSION

# ls -l "scrape"-*-"$VERSION" 2>/dev/null

ssh con rm "Downloads/scrape-linux-arm-$VERSION"
scp "scrape-linux-amd64-$VERSION" con:~/"Downloads/scrape-linux-amd64-$VERSION"
time ssh con "Downloads/scrape-linux-amd64-$VERSION"
