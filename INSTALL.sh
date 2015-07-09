#!/bin/dash
#
# Copyright (c) 2013-2015 Marcus Rohrmoser, http://purl.mro.name/radio-pi
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
#   $ curl https://raw.github.com/mro/radio-pi/master/INSTALL.sh > INSTALL.sh && dash INSTALL.sh
#

git_repo="https://github.com/mro/radio-pi.git"
www_base="/srv"     # has to match simple-vhost.server-root from /etc/lighttpd/conf-available/10-simple-vhost.conf

user="radio-pi"
group="www-data"
tmp_dir="/tmp/$user"

# check preliminaries
sudo -V > /dev/null             || { echo "Sorry, but I need that one." 1>&2 && exit 2; }
apt-get --version > /dev/null   || { echo "Sorry, but I need that one." 1>&2 && exit 2; }
apt-mark --version > /dev/null  || { echo "Sorry, but I need that one." 1>&2 && exit 2; }

me=$(basename "$0")

git_branch="$1"
if [ "" = "$git_branch" ] ; then
  git_branch="master"
fi
RECORDER_DOMAIN="$2"
echo_prefix="RadioPi:"

if [ "" = "$RECORDER_DOMAIN" ] ; then
  mkdir "$tmp_dir"                || { echo "Sorry, but I insist to create that (clean slate)." 1>&2 && exit 3; }

  apt-mark showmanual > "$tmp_dir/apt-mark.showmanual.pre"
  apt-mark showauto > "$tmp_dir/apt-mark.showauto.pre"
  
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
  sudo apt-get install git-core || { echo "$echo_prefix couldn't install git-core. Exiting..." 1>&2 && exit 3; }

  if [ -d "$recorder_base/.git" ] ; then
    echo "$echo_prefix I'm not safe to be re-run for now. Exiting..."
    exit 4
  else
    sudo git clone "$git_repo" "$recorder_base"
    cd "$recorder_base"
    sudo git checkout "$git_branch"
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
pkgs="adduser make parallel"

### job scheduler cron + at:
  pkgs="$pkgs cron at"

### lighttpd (or just any web server to serve static files + simple CGIs + some convenience redirects):
  pkgs="$pkgs lighttpd"
  # user/password database:
  pkgs="$pkgs apache2-utils"

### ruby + nokogiri (the scraper):
  # avoid ruby reinstall for non-debian ruby, e.g. http://www.rubyenterpriseedition.com/
  ruby -e "require 'mkmf'" 2>&1 > /dev/null
  if [ $? -ne 0 ] ; then
    pkgs="$pkgs ruby-dev"
  fi
  pkgs="$pkgs libxml2-dev libxslt-dev"

### xsltproc (simplified scraper):
  pkgs="$pkgs xsltproc"

### lua, luarocks, lfs:
  pkgs="$pkgs luarocks lua-posix lua-filesystem"

### streamripper:
  pkgs="$pkgs streamripper"

### id3tags:
  pkgs="$pkgs g++ libtag1-dev"

echo "$echo_prefix apt-get install $pkgs"
sudo apt-get install $pkgs
if [ $? -ne 0 ] ; then
  echo "Couldn't install all preliminaries" 1>&2
  exit 6
fi

echo "$echo_prefix Prerequisites - configuration.."

  sudo adduser --system --home="$recorder_base" --no-create-home --ingroup "$group" "$user" || { echo "Couldn't create dedicated user" 1>&2 && exit 7; }
  sudo cp "$tmp_dir"/apt-mark.show*.pre "$recorder_base/logs/"
  rm -rf "$tmp_dir"
  apt-mark showmanual | sudo tee "$recorder_base/logs/apt-mark.showmanual.post" > /dev/null
  apt-mark showauto | sudo tee "$recorder_base/logs/apt-mark.showauto.post" > /dev/null

  sudo chown -R "$user:$group" "$recorder_base" || { echo "Couldn't chown" 1>&2 && exit 8; }
  sudo chmod g+w "$recorder_base/logs"

  sudo tee /etc/sudoers.d/radio-pi >/dev/null - <<END_OF_SUDOERS
www-data ALL = ($user:$group) NOPASSWD: $recorder_base/htdocs/enclosures/app/ad_hoc.lua
#
# In case you mess up this file, repair like described here http://ubuntuforums.org/showthread.php?t=2036382&p=12144840#post12144840
# $ pkexec vim /etc/sudoers.d/radio-pi
#
END_OF_SUDOERS

### ruby + bundler (gem installation helper)
  bundle --version || sudo gem install bundler --no-ri --no-rdoc

### gems
  sudo -u "$user" bundle install --path vendor/bundle

### luarocks: lfs, posix
#  luarocks show luafilesystem 2>/dev/null || sudo luarocks install luafilesystem
#  luarocks show luaposix 2>/dev/null || sudo luarocks install luaposix

### streamripper:

### lighttpd (or just any web server to serve static files + simple CGIs + some convenience redirects):
  sudo cp "$recorder_base"/etc/lighttpd/conf-available/20-* /etc/lighttpd/conf-available
  sudo lighty-enable-mod accesslog auth cgi dir-listing simple-vhost per-vhost-config

  read -p "$echo_prefix http user (for authenticated http://$RECORDER_DOMAIN/ mp3 access): " RECORDER_HTTP_USER
  if [ "" = "$RECORDER_HTTP_USER" ] ; then
    echo "$echo_prefix no username given, exiting..."
    echo "$echo_prefix to rerun call"
    echo "    $ $0 $1"
    exit 7
  fi
  # user/password database:
  sudo htdigest -c /etc/lighttpd/radio-pi.user.htdigest 'Radio Pi' "$RECORDER_HTTP_USER"

  echo "http://$RECORDER_DOMAIN" | sudo -u "$user" tee "$recorder_base/htdocs/app/base.url"

  sudo /etc/init.d/lighttpd force-reload

### at & cron jobs

echo "# $git_repo\n$user" | sudo tee --append /etc/at.allow

sudo -u "$user" crontab -ri
sudo -u "$user" crontab - <<END_OF_CRONTAB
# crontab generated by $0 from $git_repo branch $git_branch
RADIO_PI_CRON_DIR=$recorder_base/htdocs/app/cron
12 05  * * * /bin/dash "\$RADIO_PI_CRON_DIR/daily.sh"
55 *   * * * /bin/dash "\$RADIO_PI_CRON_DIR/hourly.sh"
10 */3 * * * /bin/dash "\$RADIO_PI_CRON_DIR/cleanup.sh"
END_OF_CRONTAB
sudo -u "$user" crontab -l

echo "######################################################"
echo "Recorder install finished. For initial radio program website scrape, call"
echo "    \$ sudo -u $user $recorder_base/htdocs/app/cron/daily.sh"
echo "Follow progress via"
echo "    \$ tail -f $recorder_base/htdocs/log/*"
