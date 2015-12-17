#!/usr/bin/env ruby
# encoding: utf-8
#
# Copyright (c) 2013-2015 Marcus Rohrmoser, http://purl.mro.name/internet-radio-recorder
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
# Station-specific part of the broadcast website scraper for http://br.de.
#
# Linked to from station/<name>/app/scraper.rb, so each station can provide a custom scraper.
#
# Fires the generic driver method run_update_broadcast from Recorder::Scraper
# which in turn calls back to update_broadcasts_between here.
#
# Writing the broadcast meta data to stdout (to_lua) is currently triggered here,
# but should move to the station-agnostic htdocs/app/recorder.rb.
#

require File.join(File.dirname(File.expand_path(__FILE__)),'..','..','..','app','recorder')

require 'open-uri'
require 'peach'

module Recorder
  class BroadcastM945 < Broadcast

    @@PAT_TIME = /^\s*([0-2]\d):(\d\d)\s*$/

    def self.dtstart t0, tr
      t = tr.at_css('div.time')
      return nil if t.nil?
      m = @@PAT_TIME.match(t.text)
      m.nil? ? nil : Time.mktime(t0.year, t0.month, t0.day, m[1], m[2])
    end

    def initialize station, t0, url0, tr
      title = tr.at_css('a')
      dts = BroadcastM945::dtstart(t0, tr)
      tr.at_css('div.time').remove
      # def initialize station, dtstart, title, src_url
      super(station, dts, title.text_clean, url0)

      @DC_language = 'de'
      @DC_copyright =  "© #{Time.now.year} http://www.m945.de/"
      @DC_title = title.text_clean
      @DC_subject = url0 + title[:href] unless title[:href].nil? || '' == title[:href]
      begin
        unless @DC_subject.nil?
          doc = Nokogiri::HTML(open(@DC_subject))
          # m945 has broken og:image images
          # image_node = doc.at_xpath('/html/head/meta[@property="og:image"]')
          image_node = doc.at_css('#head_banner img')
          @DC_image = url0 + image_node[:src] unless image_node.nil?
        end
      rescue Exception => e
      end
      @DC_format_timestart = dts

      title.remove
      txt = tr.text_clean_br
      @DC_description = txt || ''

      @DC_publisher =  'http://www.m945.de/'
    end

    # attr_accessor :DC_title_series, :DC_title_episode
    # attr_accessor :DC_image
    # attr_accessor :DC_author, :DC_creator
  end

  # scraping actually happens in BroadcastM945.initialize
  class ScraperM945 < Scraper

    def initialize
      super(Station.new( File.dirname(File.dirname(File.expand_path(__FILE__))) ))
    end

    # should go into recorder.rb
    def download url
      Nokogiri::HTML(open(url))
    end

    def url_for_day t0
      @station.program_url + "?daterequest=#{t0.strftime('%F')}"
    end

    # scrape one day's program schedule
    def scrape_day t0
      url = url_for_day(t0)
      $stderr.puts url
      begin
        doc = download url
        prev_bc = nil         # lookahead: start time of next entry is end time of previous
        doc.css('div.list > div.item').each do |tr|
          dtstart = BroadcastM945::dtstart(t0, tr)
          next if dtstart.nil?
          bc = BroadcastM945.new @station, t0, url, tr
          unless prev_bc.nil?
            raise "oh" if bc.DC_format_timestart.nil?
            prev_bc.DC_format_timeend = bc.DC_format_timestart
            prev_bc.to_lua $stdout
          end
          prev_bc = bc
        end
        raise "ouch" if prev_bc.nil?
        prev_bc.DC_format_timeend = @station.curfew_for_day t0
        prev_bc.to_lua $stdout
      rescue Exception => e
        $stderr.puts e
      end
    end

    def scrape_incremental
      [0, 1, 7].collect{|dt| Time.now + dt*24*60*60}.peach{|t0| scrape_day t0}
    end
  end
end


case ARGV[0]
  when '--incremental'
    Recorder::ScraperM945.new.scrape_incremental
    exit 0
  when nil
    $stdout.puts <<EOF_OF_HERE
Rescrape broadcasts.

  --new         all missing broadcasts (actually: all future broadcasts) (not implemented !!!)
  --total       all broadcasts                                           (not implemented !!!)
  --future      all future broadcasts                                    (not implemented !!!)
  --incremental next hour, next hour tomorrow, +1 week (actually: all today, tomorrow, +1 week)

EOF_OF_HERE
    exit 0
  else
    $stderr.puts <<EOF_OF_HERE
#{__FILE__} #{ARGV.join(' ')} not implemented.
EOF_OF_HERE
end
exit 1
