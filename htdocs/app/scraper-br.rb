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
	class ScraperBR < Scraper

		def download url
			Nokogiri::HTML(open(url))
		end

		@@NUMBER_FOR_MONTH = {
			'Januar'	=> '01',
			'Februar'	=> '02',
			'März'		=> '03',
			'April'		=> '04',
			'Mai'		=> '05',
			'Juni'		=> '06',
			'Juli'		=> '07',
			'August'	=> '08',
			'September' => '09',
			'Oktober'	=> '10',
			'November'	=> '11',
			'Dezember'	=> '12'
		}

		def initialize
			super(Station.new( File.dirname(File.dirname(File.expand_path(__FILE__))) ))
			@year_for_month = {}
		end

		def update_broadcasts_between t_min, t_max, force
			$stderr.puts "#{self.class}.update_index_between  #{t_min}	-  #{t_max}"
			$stdout.puts "-- #{__FILE__}"

			t_min_day = station.day_start_for_day t_min
			t_max_day = station.day_start_for_day t_max

			# $stderr.puts "t_min_day: #{t_min_day}	   for	 #{t_min}"
			# $stderr.puts "t_max_day: #{t_max_day}	   for	 #{t_max}"

			day_queue = Queue.new
			bc_queue = Queue.new
			sema4 = Mutex.new

			# scrape calendar from program page
			day_count = 0
			each_day(@station.program_url) do |date,url|
				t = station.day_start_for_day Time.local(date[0], date[1], date[2], 0, 0, 0)
				# TODO fix: date is midnight, must not naively compare with tmin/tmax:
				if t < t_min_day || t > t_max_day
					# $stderr.puts "skip   day #{t.to_iso8601}"
					next
				end
				day_count += 1
				next unless (day_count % 3) == 1 # start with current day. In case we only scrape a single one.
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

		# scrape the url for calendar and yield dates + urls
		def each_day url, doc=download(url)
			# $stderr.puts "#{self.class}.each_day #{url}"
			month_year_regexp = Regexp.new( '(' + @@NUMBER_FOR_MONTH.keys.join('|') + ').*' + '(20\\d{2})' )
			day_regexp = Regexp.new( '(\\d{1,2})\\.\\s+(' + @@NUMBER_FOR_MONTH.keys.join('|') + ')' )
			doc.css('div.month').each do |div_month|
				div_month.css('div table').each do |month_table|
					month_year_match = month_year_regexp.match( month_table[:summary] )
					raise "Cannot parse month+year '#{month_table[:summary]}'" if month_year_match.nil?
					# check existence, block overwrites?
					@year_for_month[ @@NUMBER_FOR_MONTH[ month_year_match[1] ] ] = month_year_match[2]
					# $stderr.puts "Registered month->year #{@@NUMBER_FOR_MONTH[ month_year_match[1] ]}"
					month_table.css('tbody td a').each do |day_node|
						day_match = day_regexp.match( day_node.text )
						raise "Cannot parse day '#{day_node.text}'" if day_match.nil?
						day = '%02d' % day_match[1].to_i
						month = @@NUMBER_FOR_MONTH[ day_match[2] ]
						year = @year_for_month[ month ]
						yield [year,month,day], url + day_node[:href]
					end
				end
			end
			doc
		end

		# scrape the url for broadcasts and yield times, titles, urls
		def each_broadcast url, doc=download(url)
			# $stderr.puts "#{self.class}.each_broadcast #{url}"
			begin
				doc.css('div.day_123 div h4').each do |day_node|
					day_match = /(\d{2})\.(\d{2})/.match Scraper.clean(day_node.text)
					raise "Cannot parse day '#{day_node}'" if day_match.nil?
					day_node.parent.css('a.link_broadcast').each do |bc_node|
						time_node = bc_node.at_css('strong')
						time_match = /(\d{2}):(\d{2})/.match( time_node.text )
						raise "Cannot parse time '#{time_node}'" if time_match.nil?
						day = day_match[1]
						month = day_match[2]
						year = @year_for_month[ month ]
						raise "Sorry, I need to know the year for month '#{month}' first. Please run e.g. 'days'." if year.nil?
						time_str = "#{time_match[1]}#{time_match[2]}"
						time_node.remove
						raise 'Ouch' if @station.day_start.nil?
						if time_str < @station.day_start
							d = Date.new(year.to_i, month.to_i, day.to_i) + 1
							day	  = '%02d' % d.day
							month = '%02d' % d.month
							year  = '%04d' % d.year
						end
						title = Scraper.clean( bc_node.text )
						yield Broadcast.new( station, Time.local(year,month,day,time_match[1],time_match[2],0), title, url + bc_node[:href] )
					end
				end
				doc
			rescue Exception => e
				$stderr.puts "Exception #{e} #{e.backtrace.join("\n")}"
			end
		end

		# scrape broadcast page
		def scrape_broadcast bc, doc
			bc.DC_language = doc.at_css('html > head > meta[http-equiv="Language"]')['content']
			raise "Couldn't find language in #{bc.to_s}" if bc.DC_language.nil?
	#		broadcast[:last_modified] = Time.local(doc.at_css('html > head > meta[name="Last-Modified"]')['content'])
	#		raise "Couldn't find last_modified in #{uri}" if broadcast[:last_modified].nil?
			bc.DC_author = doc.at_css('html > head > meta[name="author"]')['content']
			raise "Couldn't find author in #{uri}" if bc.DC_author.nil?
			bc.DC_copyright = doc.at_css('html > head > meta[name="copyright"]')['content']
			raise "Couldn't find copyright in #{uri}" if bc.DC_copyright.nil?
	
			doc = doc.at_css '.detail_inlay'
	
			title_node = doc.at_css('h1.bcast_headline')
			raise "Couldn't find title in #{bc.to_s}" if title_node.nil?

			overline_node = title_node.at_css('span.bcast_overline')
			unless overline_node.nil?
				bc.DC_title_series = Scraper.clean(overline_node.text)
				overline_node.remove
			end

			subtitle_node = title_node.at_css('span.bcast_subtitle')
			unless subtitle_node.nil?
				bc.DC_title_episode = Scraper.clean(subtitle_node.text)
				subtitle_node.remove
			end

			raise "No title node found #{bc.to_s}" if title_node.nil?
			bc.DC_title = Scraper.clean(title_node.text)

			date_node = doc.at_css('div.bcast_head > div.bcast_info > p.bcast_date')
			date_regexp = /(\d{1,2})\.(\d{1,2})\.(\d{4}).*?(\d{2}):(\d{2}).*?bis.*?(\d{2}):(\d{2})/m
			raise "No date node found #{bc.to_s}" if date_node.nil?
			date_match = date_regexp.match(date_node.text)
			raise "Couldn't parse date '#{date_node}' #{bc.to_s}" if date_match.nil?

			bc.DC_format_timestart = Time.local date_match[3].to_i, date_match[2].to_i, date_match[1].to_i, date_match[4].to_i, date_match[5].to_i
			bc.DC_format_timeend = Time.local date_match[3].to_i, date_match[2].to_i, date_match[1].to_i, date_match[6].to_i, date_match[7].to_i
			bc.DC_format_timeend = bc.DC_format_timeend.add_one_day if bc.DC_format_timeend < bc.DC_format_timestart
			bc.DC_format_duration = bc.DC_format_timeend - bc.DC_format_timestart

			bc.DC_description = ''
			doc.css('>p').each do |p_node|
				# http://rubyforge.org/pipermail/nokogiri-talk/2009-January/000031.html
				p_node.search('br').each{ |br| br.replace(Nokogiri::XML::Text.new("\n", p_node.document))}
				c = p_node.content
				c.gsub! /[ \t]+/, ' '
				bc.DC_description << c.strip << "\n\n"
			end
			bc.DC_description.gsub! /[ \t]*\n[ \t]*/, "\n"
			bc.DC_description.gsub! /\n(\s*\n)+/, "\n\n"
			bc.DC_description.strip!

			# image_thumb_node = doc.at_css('.teaser_picture img')
			# image_thumb = uri + image_thumb_node[:src] unless image_thumb_node.nil?

			image_node = doc.at_css('div.bcast_head > div.detail_picture_256 img')
			bc.DC_image = bc.src_url + image_node[:src] unless image_node.nil?
		end
	end
end


###############################################################################
##	the actual commandline script interface
###############################################################################

Recorder::ScraperBR.new.run_update_broadcast
