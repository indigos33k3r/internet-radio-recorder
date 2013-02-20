#!/bin/sh

# Install
## Prerequisites

### lighttpd (or just any web server to serve static files + simple CGIs + some convenience redirects):
    sudo apt-get install lighttpd lighttpd-doc
    # t.b.d.: config + password directory protection

### ruby + nokogiri (the scraper):
    sudo apt-get install ruby ruby-dev libxml2-dev libxslt-dev
    sudo gem install nokogiri

### lua, luarocks, lfs:
    sudo apt-get install lua luarocks
    sudo luarocks install luafilesystem

### streamripper:
    sudo apt-get install streamripper

### id3tags:
	sudo apt-get install libtag1-dev
	sudo gem install taglib-ruby -v 0.4.0
    # https://bitbucket.org/jfsantos/ltaglib/overview
    # https://github.com/fur-q/ltaglib/

## cronjobs
    sudo su -c "EDITOR=vi crontab -e" www-data
    # 12   5 * * * /bin/sh /srv/.../htdocs/app/cron/daily.sh
    # 55   * * * * /bin/sh /srv/.../htdocs/app/cron/hourly.sh
    # *    * * * * /bin/sh /srv/.../htdocs/app/cron/minutely.sh
    # 10 */3 * * * /bin/sh /srv/.../htdocs/app/cron/cleanup.sh
