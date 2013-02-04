#!/bin/sh

# Install script (t.b.d.)

	# get sources, e.g. clone from github:
	git clone git://github.com/mro/br-recorder.git

	# run installer
	sh br-recorder/install.sh
	
exit

# Manual Install

## Prerequisites

### lighttpd (or just any web server to serve static files + simple CGIs + some convenience redirects):
    sudo apt-get install lighttpd lighttpd-doc
    sudo lighty-enable-mod accesslog auth cgi dir-listing simple-vhost
    # user/password database:
    sudo apt-get install apache2-utils 
    sudo htdigest -c /etc/lighttpd/lighttpd.user.htdigest 'Recorder br radio' rec-user

### ruby + nokogiri (the scraper):
    sudo apt-get install ruby ruby-dev libxml2-dev libxslt-dev
    sudo gem install nokogiri

### lua, luarocks, lfs:
    sudo apt-get install lua luarocks
    sudo luarocks install luafilesystem

### streamripper:
    sudo apt-get install streamripper

### id3tags:
    # https://bitbucket.org/jfsantos/ltaglib/overview
    # https://github.com/fur-q/ltaglib/

## Recorder application

	# get sources, e.g. clone from github:
	git clone git://github.com/mro/br-recorder.git

	# set baseurl (subdomain assumed, running in a subdir is a bit more complicated, see also server.conf)
	echo "http://recorder.example.com" > br-recorder/htdocs/app/base.url

	# strip git repo and move to lighttpd vhost dir
	rm -rf br-recorder/.git
	sudo mv br-recorder /srv/recorder.example.com
	sudo chown -R www-data:www-data /srv/recorder.example.com

	# (re-)start lighttpd
	sudo /etc/init.d/lighttpd force-reload

	# initial launch (no need to wait until daily cronjob fires 1st time):
	sudo -u www-data /bin/sh /srv/recorder.example.com/app/cron/daily.sh

## cronjobs
    sudo -u www-data EDITOR=vi crontab -l
	# RECORDER_BASE_DIR=/srv/recorder.example.com
	# 12 05  * * * /bin/sh "$RECORDER_BASE_DIR/app/cron/daily.sh"
	# 55  *  * * * /bin/sh "$RECORDER_BASE_DIR/app/cron/hourly.sh"
	# *   *  * * * /bin/sh "$RECORDER_BASE_DIR/app/cron/minutely.sh"
	# 10 */3 * * * /bin/sh "$RECORDER_BASE_DIR/app/cron/cleanup.sh"
