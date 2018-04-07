#!/bin/sh
# https://golang.org/doc/install/source#environment
#

cd "$(dirname "${0}")"
# $ uname -s -m
# Darwin x86_64
# Linux x86_64
# Linux armv6l

PROG_NAME="enclosure-tag"
VERSION="0.0.2"

rm "${PROG_NAME}"-*-"${VERSION}" 2>/dev/null

# curl --output "testdata/artwork.jpg" "http://www.br.de/radio/bayern2/wissen/radiowissen/herodes-festung-100~_v-img__16__9__m_-4423061158a17f4152aef84861ed0243214ae6e7.jpg?version=6f858"
# curl --output "testdata/file.mp3" "https://raw.githubusercontent.com/mikkyang/id3-go/master/test.mp3"

# cd ../scrape
go get -u "github.com/bogem/id3v2"
go get -u "github.com/stretchr/testify"

cp "${GOPATH}/src/github.com/bogem/id3v2/testdata/test.mp3" "./testdata/file.mp3"
cp "${GOPATH}/src/github.com/bogem/id3v2/testdata/back_cover.jpg" "./testdata/image.jpg"

CWD="$(pwd)"
cd ..
for dir in "${PROG_NAME}-cmd"
do
  cd "${CWD}/../${dir}"
  go fmt && go test ; \
  {
    echo "<html><head>"
    echo "<meta http-equiv='Content-type' content='text/html; charset=utf-8' />"
    echo "<title>go package 'purl.mro.name/recorder/radio/${dir}'</title>"
    echo "</head><body>"
    godoc -html "purl.mro.name/recorder/radio/${dir}"
  } | tidy -utf8 -asxhtml -indent -wrap 100 -quiet - 2>/dev/null > index.html
done
cd "${CWD}"

# http://dave.cheney.net/2015/08/22/cross-compilation-with-go-1-5
env GOOS=linux GOARCH=arm GOARM=6 go build -o "${PROG_NAME}-linux-arm-${VERSION}"
env GOOS=linux GOARCH=amd64 go build -o "${PROG_NAME}-linux-amd64-${VERSION}"
env GOOS=linux GOARCH=386 GO386=387 go build -o "${PROG_NAME}-linux-386-${VERSION}" # https://github.com/golang/go/issues/11631
env GOOS=darwin GOARCH=amd64 go build -o "${PROG_NAME}-darwin-amd64-${VERSION}"

# ls -l "scrape"-*-"$VERSION" 2>/dev/null

# ssh raspi rm "Downloads/scrape-linux-arm-$VERSION"
# scp "scrape-linux-arm-$VERSION" raspi:~/"Downloads/scrape-linux-arm-$VERSION"
# time ssh raspi "Downloads/scrape-linux-arm-$VERSION"

ssh con rm "Downloads/${PROG_NAME}-Linux-amd64-${VERSION}"
scp "${PROG_NAME}-linux-amd64-$VERSION" con:~/"Downloads/${PROG_NAME}-Linux-x86_64-${VERSION}"
# time ssh con "Downloads/${PROG_NAME}-linux-amd64-${VERSION}"
