#!/usr/bin/env ruby
# encoding: utf-8
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
require 'rubygems'
require 'nokogiri'

module Recorder
  class ScraperM945 < Scraper

    def download url
      Nokogiri::HTML(open(url))
    end

    def initialize
      super(Station.new( File.dirname(File.dirname(File.expand_path(__FILE__))) ))
      @year_for_month = {}
    end

    def update_broadcasts_between t_min, t_max, force
      $stderr.puts "#{self.class}.update_index_between  #{t_min}  -  #{t_max}"
      $stdout.puts "-- #{__FILE__}"

      t_min_day = station.day_start_for_day t_min
      t_max_day = station.day_start_for_day t_max

      # $stderr.puts "t_min_day: #{t_min_day}    for   #{t_min}"
      # $stderr.puts "t_max_day: #{t_max_day}    for   #{t_max}"

      day_queue = Queue.new
      bc_queue = Queue.new
      sema4 = Mutex.new

      # scrape calendar from program page
      day_count = 0
      each_day(@station.program_url) do |url|
        day_count += 1
        # queue up each (day) page to scrape:
        day_queue << proc do
          sema4.synchronize { $stderr.puts url }
          each_broadcast(url) do |broadcast|
            # TODO apply tmin/tmax filter
            if broadcast.dtstart < t_min || broadcast.dtstart > t_max
              # $stderr.puts "skip   #{broadcast.to_s}"
              next
            end
            next unless force || ! broadcast.exists?
            # queue up each (broadcast) page to scrape:
            bc_queue << proc do
              begin
                t0 = Time.now
                doc = download(broadcast.src_url) # if force || ! broadcast.exists?
                t1 = Time.now
                scrape_broadcast( broadcast, doc ) unless doc.nil?
                t2 = Time.now
                sema4.synchronize do
                  broadcast.to_lua $stdout, t0, t1, t2
                  $stderr.puts "scraped #{broadcast.to_s} (#{t1-t0}s, #{t2-t1}s)"
                end
              rescue Exception => e
                sema4.synchronize { $stderr.puts "Exception #{e} #{e.backtrace.join("\n")}" }
              end
            end

          end
        end
      end

      # $stderr.puts "STARTING DAY scrape workers"
      day_queue << Thread::END_OF_QUEUE
      Thread.prepare_workers(10, day_queue).each {|w| w.join}

      # $stderr.puts "STARTING BROADCAST scrape workers"
      bc_queue << Thread::END_OF_QUEUE
      Thread.prepare_workers(10, bc_queue).each {|w| w.join}

      $stdout.flush
    end

  private

    # scrape the url for wek overview and yield urls
    def each_day url, doc=download(url)
      doc.css('.heading1 a').each do |week_node|
        doc2 = download(url + week_node[:href])
        doc2.css('.wd a').each { |a_wday| yield url + a_wday[:href] }
      end
      doc
    end

    # scrape the url for broadcasts and yield times, titles, urls
    def each_broadcast url, doc=download(url)
      # $stderr.puts "#{self.class}.each_broadcast #{url}"
      begin
        day_node = doc.at_css('#col-left h1')
        day_match = /\s+(\d+)\.(\d+)\.(\d+)/.match day_node.text
        raise "Cannot parse day '#{day_node}'" if day_match.nil?
        day = day_match[1]
        month = day_match[2]
        year = day_match[3]
        doc.css('#col-left .item').each do |bc_node|
          time_node = bc_node.at_css('.time')
          next if time_node.nil?
          time_match = /(\d+):(\d+)/.match time_node.text
          raise "Cannot parse time '#{time_node}'" if time_match.nil?

          title_node = bc_node.at_css('.descr a')
          title = Scraper.clean( title_node.text )
          title_href = title_node[:href]
          title_node.remove

          schedule_node = bc_node.at_css('.bold')
          schedule_match = /\s+bis\s+(\d+)\s+Uhr/.match schedule_node.text
          raise "Cannot parse schedule '#{schedule_node}'" if schedule_match.nil?
          schedule_node.remove

          bc = Broadcast.new( station, Time.local(year,month,day,time_match[1],time_match[2],0), title, url + title_href )
          bc.DC_title_series = Scraper.clean( bc_node.text )
          yield bc
        end
        doc
      rescue Exception => e
        $stderr.puts "Exception #{e} #{e.backtrace.join("\n")}"
      end
    end

    # scrape broadcast page
    def scrape_broadcast bc, doc
      bc.DC_language = doc.at_css('html > head > meta[http-equiv="Content-Language"]')['content']
      raise "Couldn't find language in #{bc.to_s}" if bc.DC_language.nil?
      #   broadcast[:last_modified] = Time.local(doc.at_css('html > head > meta[name="Last-Modified"]')['content'])
      #   raise "Couldn't find last_modified in #{uri}" if broadcast[:last_modified].nil?
      bc.DC_author = doc.at_css('html > head > meta[name="publisher"]')['content']
      raise "Couldn't find author in #{uri}" if bc.DC_author.nil?
      bc.DC_copyright = doc.at_css('html > head > meta[name="copyright"]')['content']
      raise "Couldn't find copyright in #{uri}" if bc.DC_copyright.nil?

      title_node = doc.at_css('#col-left h1')
      raise "Couldn't find title in #{bc.to_s}" if title_node.nil?
      bc.DC_title = Scraper.clean(title_node.text)

      dtend_node = doc.at_css('.bold')
      dtend_match = /von\s+(\d+)\s+bis\s+(\d+)\s+Uhr/.match dtend_node.text
      raise "Couldn't find start/end in #{dtend_node.text}" if dtend_match.nil?

      # $stderr.puts "dtstart: #{bc.dtstart} - #{dtend_match[2]}"

      bc.DC_format_timestart = bc.dtstart
      bc.DC_format_timeend = Time.local bc.dtstart.year, bc.dtstart.month, bc.dtstart.day, dtend_match[2].to_i, 0
      bc.DC_format_timeend = bc.DC_format_timeend.add_one_day if bc.DC_format_timeend < bc.DC_format_timestart
      bc.DC_format_duration = bc.DC_format_timeend - bc.DC_format_timestart

      bc.DC_description = ''
      doc.css('.floating').each do |p_node|
        # http://rubyforge.org/pipermail/nokogiri-talk/2009-January/000031.html
        p_node.search('br').each{ |br| br.replace(Nokogiri::XML::Text.new("\n", p_node.document))}
        c = p_node.content
        c.gsub! /[ \t]+/, ' '
        bc.DC_description << c.strip << "\n\n"
      end
      bc.DC_description.gsub! /[ \t]*\n[ \t]*/, "\n"
      bc.DC_description.gsub! /\n(\s*\n)+/, "\n\n"
      bc.DC_description.strip!
    end
  end
end


###############################################################################
##  the actual commandline script interface
###############################################################################

Recorder::ScraperM945.new.run_update_broadcast
