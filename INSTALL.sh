#!/bin/dash
#
# Copyright (c) 2013 Marcus Rohrmoser, https://github.com/mro/radio-pi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
# OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# MIT License http://opensource.org/licenses/MIT
#
#
# INSTALLATION
#
#	  $ curl https://raw.github.com/mro/radio-pi/master/INSTALL.sh > INSTALL.sh && dash INSTALL.sh
#

git_repo="git://github.com/mro/radio-pi.git"
www_base="/srv"			# has to match simple-vhost.server-root from /etc/lighttpd/conf-available/10-simple-vhost.conf

me=$(basename "$0")

git_branch="$1"
if [ "" = "$git_branch" ] ; then
	git_branch="master"
fi
RECORDER_DOMAIN="$2"
echo_prefix="RadioPi:"

if [ "" = "$RECORDER_DOMAIN" ] ; then
	echo "$echo_prefix installing radio-pi from $git_repo to /srv/<recorder.example.com>"
	read -p "$echo_prefix domain (e.g. recorder.example.com): " RECORDER_DOMAIN
	if [ "" = "$RECORDER_DOMAIN" ] ; then
		echo "$echo_prefix no domain given, exiting..."
		exit 1
	fi

	recorder_base="$www_base/$RECORDER_DOMAIN"

	cd "$www_base"
	if [ $? -ne 0 ] ; then exit 2; fi
	echo "$echo_prefix creating $recorder_base..."

	echo "$echo_prefix grabbing git repo $git_repo ..."
	sudo apt-get install git-core
	if [ $? -ne 0 ] ; then
		echo "$echo_prefix couldn't install git-core. Exiting..."
		exit 3
	fi

	if [ -d "$recorder_base/.git" ] ; then
		echo "$echo_prefix I'm not safe to be re-run for now. Exiting..."
		exit 4
		# cd "$RECORDER_DOMAIN"
		# sudo git pull
	else
		sudo git clone "$git_repo" "$recorder_base"
		sudo chown -R "$USER:www-data" "$recorder_base"
		cd "$recorder_base"
		git checkout "$git_branch"
	fi
	if [ $? -ne 0 ] ; then
		echo "$echo_prefix couldn't fetch git-repo. Exiting..."
		exit 5
	fi

	echo "$echo_prefix handing over to $me from git..."
	dash "$me" "$git_branch" "$RECORDER_DOMAIN"
	exit 0
else
	recorder_base="$www_base/$RECORDER_DOMAIN"
	echo "$echo_prefix Continue install for recorder domain '$RECORDER_DOMAIN' ($git_branch)..."
fi

echo "$echo_prefix Prerequisites - apt packages"
pkgs="make"

### job scheduler cron + at:
	pkgs="$pkgs cron at"

### lighttpd (or just any web server to serve static files + simple CGIs + some convenience redirects):
	pkgs="$pkgs lighttpd lighttpd-doc"
	# user/password database:
	pkgs="$pkgs apache2-utils"

### ruby + nokogiri (the scraper):
	# avoid ruby reinstall for non-debian ruby, e.g. http://www.rubyenterpriseedition.com/
	ruby -e puts > /dev/null
	if [ $? -ne 0 ] ; then
		pkgs="$pkgs ruby ruby-dev"
	fi
	pkgs="$pkgs libxml2-dev libxslt-dev"

### xsltproc (simplified scraper):
	pkgs="$pkgs xsltproc"

### lua, luarocks, lfs:
	pkgs="$pkgs lua5.1 luarocks"

### streamripper:
	pkgs="$pkgs streamripper"

### id3tags:
	pkgs="$pkgs libtag1-dev"

echo "$echo_prefix apt-get install $pkgs"
sudo apt-get install $pkgs
if [ $? -ne 0 ] ; then exit 6; fi

echo "$echo_prefix Prerequisites - configuration.."

### ruby + nokogiri (the scraper):
	gem list --installed "^nokogiri$" 1>/dev/null
	if [ 0 -ne $? ] ; then
		sudo gem install nokogiri
	fi

### id3tags:
	# had issues with more recent on OSX ( or was it debian amd_64?)
	gem list --installed "^taglib-ruby$" 1>/dev/null
	if [ 0 -ne $? ] ; then
		sudo gem install taglib-ruby -v 0.4.0
	fi

### lua, luarocks, lfs:
	luarocks show luafilesystem 1>/dev/null
	if [ 0 -ne $? ] ; then
		sudo luarocks install luafilesystem
	fi
	luarocks show luaposix 1>/dev/null
	if [ 0 -ne $? ] ; then
		# had issues with 5.1.25-1 on debian amd_64
		sudo luarocks install luaposix 5.1.24-1
	fi

### streamripper:

### lighttpd (or just any web server to serve static files + simple CGIs + some convenience redirects):
	sudo cp "$recorder_base"/conf-available/20-* /etc/lighttpd/conf-available
	sudo lighty-enable-mod accesslog auth cgi dir-listing simple-vhost per-vhost-config

	read -p "$echo_prefix http user (for authenticated http://$RECORDER_DOMAIN/ mp3 access): " RECORDER_HTTP_USER
	if [ "" = "$RECORDER_HTTP_USER" ] ; then
		echo "$echo_prefix no username given, exiting..."
		echo "$echo_prefix to rerun call"
		echo "	  $ $0 $1"
		exit 7
	fi
	# user/password database:
	sudo htdigest -c /etc/lighttpd/radio-pi.user.htdigest 'Radio Pi' "$RECORDER_HTTP_USER"

	sudo chown -R "www-data:www-data" "$recorder_base"
	if [ $? -ne 0 ] ; then exit 8; fi

	echo "http://$RECORDER_DOMAIN" | sudo -u www-data tee "$recorder_base/htdocs/app/base.url"

	sudo /etc/init.d/lighttpd force-reload

### at & cron jobs

echo "# $git_repo\nwww-data" | sudo tee /etc/at.allow

sudo -u www-data crontab -ri
sudo -u www-data crontab - <<END_OF_CRONTAB
# crontab generated by $0 from $git_repo branch $git_branch
RADIO_PI_CRON_DIR=$recorder_base/htdocs/app/cron
12 05  * * * /bin/dash "\$RADIO_PI_CRON_DIR/daily.sh"
55 *   * * * /bin/dash "\$RADIO_PI_CRON_DIR/hourly.sh"
10 */3 * * * /bin/dash "\$RADIO_PI_CRON_DIR/cleanup.sh"
END_OF_CRONTAB
sudo -u www-data crontab -l

echo "######################################################"
echo "Recorder install finished. For initial radio program website scrape, call"
echo "	  \$ sudo -u www-data $recorder_base/htdocs/app/cron/daily.sh"
echo "Follow progress via"
echo "	  \$ tail -f $recorder_base/htdocs/log/*"
