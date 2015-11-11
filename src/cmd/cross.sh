#!/bin/sh
# https://golang.org/doc/install/source#environment
#

cd "$(dirname "$0")"

VERSION=0.0.1

rm "scrape"-*-"$VERSION" 2>/dev/null

# cd ../scrape
go get github.com/yhat/scrape
go get github.com/stretchr/testify

CWD="$(pwd)"
for dir in . ../scrape ../scrape/br ../scrape/dlf ../scrape/m945
do
  cd "$CWD/$dir"
  go fmt
  go test 
done
cd "$CWD"

# http://dave.cheney.net/2015/08/22/cross-compilation-with-go-1-5
env GOOS=linux GOARCH=arm GOARM=6 go build -o scrape-linux-arm-$VERSION
# env GOOS=linux GOARCH=amd64 go build -o scrape-linux-amd64-$VERSION
# env GOOS=darwin GOARCH=amd64 go build -o scrape-darwin-amd64-$VERSION

# ls -l "scrape"-*-"$VERSION" 2>/dev/null

ssh raspi rm "Downloads/scrape-linux-arm-$VERSION"
scp "scrape-linux-arm-$VERSION" raspi:~/"Downloads/scrape-linux-arm-$VERSION"
time ssh raspi "Downloads/scrape-linux-arm-$VERSION"

exit 0

ssh con rm "Downloads/scrape-linux-amd64-$VERSION"
scp "scrape-linux-amd64-$VERSION" con:~/"Downloads/scrape-linux-amd64-$VERSION"
time ssh con "Downloads/scrape-linux-amd64-$VERSION"
