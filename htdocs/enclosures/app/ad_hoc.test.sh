#!/bin/sh

export REQUEST_METHOD=POST

# export QUERY_STRING='uri=referer'
export HTTP_REFERER='stations/b4/2013/01/01/0000%20Mit%20dem%20ARD-Nachtkonzert%20ins%20Neue%20Jahr.html'
# lua "$(dirname "$0")"/schedule.lua

# export QUERY_STRING='uri=referer'
export HTTP_REFERER='stations/b4/2013/03/05/0503%20ARD%20Nachtkonzert.html'
# export HTTP_REFERER='http://rec.domus.mro.name/stations/b2/2013/01/15/1605%20Eins%20zu%20Eins.%20Der%20Talk.html'
export CONTENT_LENGTH=10
echo "action=add" | lua "$(dirname "$0")"/ad_hoc.lua