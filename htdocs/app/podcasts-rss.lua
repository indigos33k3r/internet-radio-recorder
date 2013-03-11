#!/usr/bin/env lua
-- ensure Recorder.lua (next to this file) is found:
package.path = arg[0]:gsub("/[^/]+/?$", '') .. "/?.lua;" .. package.path
require'Recorder'
Recorder.chdir2app_root( arg[0] )

for _,pc in pairs(Podcast:each()) do
	local file,msg,err = pc:save_rss()
	if file then
		io.stderr:write(msg, ' ', file, "\n")
	else
		io.stderr:write(msg, ' ', err, "\n")
	end
end