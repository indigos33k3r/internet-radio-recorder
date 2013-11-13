#!/bin/sh
cd "$(dirname "$0")"/../..

export QUERY_STRING="station=b2&t=2013-12-14:38:00+01:00"

lua app/now.lua
