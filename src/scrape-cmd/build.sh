#!/bin/sh
# https://golang.org/doc/install/source#environment
#

cd "$(dirname "${0}")"
# $ uname -s -m
# Darwin x86_64
# Linux x86_64
# Linux armv6l

PROG_NAME="scrape"
VERSION="0.2.6"

rm "${PROG_NAME}"-*-"${VERSION}" 2>/dev/null

# cd ../scrape
go get -u github.com/yhat/scrape
go get -u github.com/stretchr/testify

CWD="$(pwd)"
cd ..
for dir in scrape-cmd scrape scrape/br scrape/b3 scrape/b4 scrape/dlf scrape/m945 scrape/radiofabrik scrape/wdr
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

dst="Downloads/${PROG_NAME}-Linux-x86_64-${VERSION}"
# dst=`ssh con echo "Downloads/${PROG_NAME}-\$(uname -s)-\$(uname -m)-${VERSION}"`
ssh con rm "${dst}"
scp "${PROG_NAME}-linux-amd64-$VERSION" con:~/"${dst}"
# time ssh con "Downloads/${PROG_NAME}-linux-amd64-${VERSION}"
