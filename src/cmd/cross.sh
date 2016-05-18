#!/bin/sh
# https://golang.org/doc/install/source#environment
#

cd "$(dirname "$0")"
# $ uname -s -m
# Darwin x86_64
# Linux x86_64
# Linux armv6l

VERSION=0.2.1

rm "scrape"-*-"$VERSION" 2>/dev/null

# cd ../scrape
go get github.com/yhat/scrape
go get github.com/stretchr/testify

CWD="$(pwd)"
cd ..
for dir in cmd scrape scrape/br scrape/b4 scrape/dlf scrape/m945 scrape/radiofabrik
do
  cd "$CWD/../$dir"
  go fmt && go test && \
  {
    echo "<html><head>"
    echo "<meta http-equiv='Content-type' content='text/html; charset=utf-8' />"
    echo "<title>go package 'purl.mro.name/recorder/radio/$dir'</title>"
    echo "</head><body>"
    godoc -html "purl.mro.name/recorder/radio/$dir"
  } | tidy -utf8 -asxhtml -indent -wrap 100 -quiet - 2>/dev/null > index.html
done
cd "$CWD"

# http://dave.cheney.net/2015/08/22/cross-compilation-with-go-1-5
env GOOS=linux GOARCH=arm GOARM=6 go build -o scrape-linux-arm-$VERSION
env GOOS=linux GOARCH=amd64 go build -o scrape-linux-amd64-$VERSION
env GOOS=darwin GOARCH=amd64 go build -o scrape-darwin-amd64-$VERSION

# ls -l "scrape"-*-"$VERSION" 2>/dev/null

# ssh raspi rm "Downloads/scrape-linux-arm-$VERSION"
# scp "scrape-linux-arm-$VERSION" raspi:~/"Downloads/scrape-linux-arm-$VERSION"
# time ssh raspi "Downloads/scrape-linux-arm-$VERSION"

ssh con rm "Downloads/scrape-linux-amd64-$VERSION"
scp "scrape-linux-amd64-$VERSION" con:~/"Downloads/scrape-Linux-x86_64-$VERSION"
# time ssh con "Downloads/scrape-linux-amd64-$VERSION"
