
A simplistic private radio podcast maker for http://br.de/radio/ broadcasts.

Built lightweight to run nicely on a raspi - http://www.raspberrypi.org/

https://github.com/mro/radio-pi


INSTALLATION

    $ curl https://raw.github.com/mro/radio-pi/master/INSTALL.sh > INSTALL.sh && dash INSTALL.sh


CREDITS
    - https://github.com/henix/slt2 (MIT License)
    - https://github.com/jquery (MIT License)


COMMON TASKS

Add a Radio Station
	- provide basic data about the station in stations/<name>/app/station.cfg
	- write a runnable scraper stations/<name>/app/scraper.rb (see stations/b2/app/scraper.rb)
	- provide stations/<name>/app/broadcast2html.xslt (see stations/b2/app/broadcast2html.xslt)
	- wait until daily cron job picks up or run manually (sudo -u www-data htdocs/app/cron/daily.sh)
	- find broadcast xmls in stations/<name>/<year>/<month>/<day>

Add a Podcast to record
	- provide basic data in podcasts/<name>/app/podcast.cfg
	- modify the 'match' lua function (see podcasts/krimi/app/podcast.cfg)
	- provide podcasts/<name>/app/podcast.slt2.rss (see app/podcast.slt2.rss)
	- wait until hourly cron job picks up or run manually (sudo -u www-data htdocs/app/cron/hourly.sh)
	- find matched broadcasts in podcasts/<name>/<station>/<year>/<month>/<day>
	- find enclosures in enclosures/<station>/<year>/<month>/<day>
