Build Status: https://travis-ci.org/mro/internet-radio-recorder/

A internet radio recorder. Turns broadcasts of e.g. http://br.de/radio/, http://m945.de/ or http://dlf.de/ into RSS feeds with mp3 enclosures.

Scrapes the websites to get proper descriptions, then does a match and schedules recordings in case.

Built lightweight to run nicely on a raspi - http://www.raspberrypi.org/ - or any other debian-like system.

http://purl.mro.name/recorder


INSTALLATION

    $ curl https://raw.github.com/mro/internet-radio-recorder/master/INSTALL.sh > INSTALL.sh && dash INSTALL.sh


CREDITS
    - http://jquery.com/ (MIT License)
    - http://momentjs.com/ (MIT License)
    - https://github.com/henix/slt2 (MIT License)


COMMON TASKS

Add a Radio Station
    - provide basic data about the station in stations/<name>/app/station.cfg
    - write a runnable scraper stations/<name>/app/scraper.rb (see stations/b2/app/scraper.rb)
    - wait until daily cron job picks up or run manually (sudo -u www-data htdocs/app/cron/daily.sh)
    - find broadcast xmls in stations/<name>/<year>/<month>/<day>

Add a Podcast to record
    - provide basic data in podcasts/<name>/app/podcast.cfg
    - modify the 'match' lua function (see podcasts/krimi/app/podcast.cfg)
    - wait until hourly cron job picks up or run manually (sudo -u www-data htdocs/app/cron/hourly.sh)
    - find matched broadcasts in podcasts/<name>/<station>/<year>/<month>/<day>
    - find enclosures in enclosures/<station>/<year>/<month>/<day>


SIMILAR

    - https://github.com/DirkR/capturadio
    - https://github.com/cosmovision/radiorecorder
    - https://github.com/prop/radio-recorder
    - https://github.com/BenHammersley/RadioPod
    - https://github.com/MiczFlor/streamplan (http://www.sourcefabric.org/en/community/blog/2077/)
    - http://www.stefan-lehnert.de/wortpresse/?p=2355 (recipe)
