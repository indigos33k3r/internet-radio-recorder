#!/usr/bin/env lua
-- ensure Recorder.lua (next to this file) is found:
package.path = arg[0]:gsub("/[^/]+/?$", '') .. "/?.lua;" .. package.path
require'Recorder'
Recorder.chdir2app_root( arg[0] )

for _,pc in pairs(Podcast:each()) do
	local ok,file,msg,err = pcall(Podcast.save_rss, pc)
	if ok and file then
		io.stderr:write(msg, ' ', file, "\n")
	else
		if not ok then
			err = file
			msg = 'fatal'
		end
		io.stderr:write(msg, ' ', err, "\n")
	end
end
