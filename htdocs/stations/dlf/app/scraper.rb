#!/usr/bin/env ruby
# encoding: utf-8
#
#  Copyright (c) 2013-2015 Marcus Rohrmoser, http://purl.mro.name/radio-pi
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
#  associated documentation files (the "Software"), to deal in the Software without restriction,
#  including without limitation the rights to use, copy, modify, merge, publish, distribute,
#  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all copies or
#  substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
#  NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
#  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#  MIT License http://opensource.org/licenses/MIT

require File.join(File.dirname(File.expand_path(__FILE__)),'..','..','..','app','recorder')
require 'open-uri'
require 'peach'

module Recorder
  class BroadcastDLF < Broadcast

    @@PAT_ANCHOR = /^anc([0-2]\d)(\d\d)$/
    @@PAT_REC    = /-recorder-programmieren\./

    def self.dtstart t0, tr
      anc = @@PAT_ANCHOR.match(tr[:id])
      anc.nil? ? nil : Time.mktime(t0.year, t0.month, t0.day, anc[1], anc[2])
    end

    def initialize station, t0, url0, tr
      tr.css('a').each{|a| a.remove unless @@PAT_REC.match(a[:href]).nil? }
      title = tr.at_css('h3')
      dts = BroadcastDLF::dtstart(t0, tr)
      # def initialize station, dtstart, title, src_url
      super(station, dts, title.text_clean, url0 + ('#' + tr[:id]))

      @DC_language = 'de'
      @DC_copyright =  "© #{Time.now.year} http://www.deutschlandfunk.de/"
      @DC_title = title.text_clean
      a = title.at_css('a')
      @DC_subject = url0 + a[:href] unless a.nil?
      @DC_format_timestart = dts

      title.remove
      tr.at_css('td').remove
      txt = tr.at_css('td').text_clean_par
      @DC_description = txt || ''

      @DC_publisher =  'http://www.deutschlandfunk.de/'
    end

    # attr_accessor :DC_title_series, :DC_title_episode
    # attr_accessor :DC_image
    # attr_accessor :DC_author, :DC_creator
  end

  # scraping actually happens in BroadcastDLF.initialize
  class ScraperDLF < Scraper

    def initialize
      super(Station.new( File.dirname(File.dirname(File.expand_path(__FILE__))) ))
    end

    # should go into recorder.rb
    def download url
      Nokogiri::HTML(open(url))
    end

    def url_for_day t0
      @station.program_url + "?drbm:date=#{t0.strftime('%d.%m.%Y')}"
    end

    # scrape one day's program schedule
    def scrape_day t0
      url = url_for_day(t0)
      $stderr.puts url
      begin
        doc = download url
        prev_bc = nil					# lookahead: start time of next entry is end time of previous
        doc.css('tr').each do |tr|
          dtstart = BroadcastDLF::dtstart(t0, tr)
          next if dtstart.nil?
          bc = BroadcastDLF.new @station, t0, url, tr
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
      [0, 1, 7, 49].collect{|dt| Time.now + dt*24*60*60}.peach{|t0| scrape_day t0}
    end
  end
end


case ARGV[0]
  when '--incremental'
    Recorder::ScraperDLF.new.scrape_incremental
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
