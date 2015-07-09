# encoding: utf-8
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
# Station-agnostic part of the broadcast website scraper machine.
#
# Assumes run_update_broadcast is called from the station specific scraper
# and calls back to update_broadcasts_between there.
#
# Writing the broadcast meta data to stdout (to_lua) is currently triggered in the
# station-specific part, but should move here.
#

require 'date'

class Time
  def add_one_day
    tmp = self.utc
    tmp = DateTime.new tmp.year, tmp.month, tmp.day, tmp.hour, tmp.min
    tmp += 1
    Time.utc(tmp.year, tmp.month, tmp.day, tmp.hour, tmp.min).localtime
  end

  def to_iso8601
    # http://www.w3.org/TR/xmlschema-2/#dateTime-timezones
    # http://stackoverflow.com/a/8569531/349514
    tz = "#{self.gmt_offset < 0 ? "-" : "+"}%02d:%02d" % (self.gmt_offset/60).abs.divmod(60)
    self.strftime('%FT%T') + tz
  end

  # http://www.faqs.org/rfcs/rfc2822.html
  def to_rfc822
    self.strftime '%a, %m %b %y %H:%M:%S %Z'
  end
end

require 'thread'

class Thread
  END_OF_QUEUE = :END_OF_QUEUE
  def self.prepare_workers count, queue
    ret = []
    1.upto(count) do |i|
      ret << Thread.new(i, queue) do |i, queue|
        loop do
          job = queue.pop
          if job == END_OF_QUEUE
            queue << job
            break
          end
          begin
            job.call
          rescue Exception => e
            $stderr.puts "error   #{job} #{e} #{e.backtrace.join("\n")}"
          end
        end
      end
    end
    ret
  end
end

require 'nokogiri'

class Nokogiri::XML::Element
  def text_clean
    txt = self.text
    txt.nil? ? txt : txt.gsub("\u00A0",' ').gsub(/\s+/, ' ').strip
  end

  def text_clean_br
    self.search('br').each{|br| br.replace(Nokogiri::XML::Text.new("\n", self.document))}
    c = self.content
    c.gsub! "\u00A0", ' '	# nbsp
    c.gsub! /[ \t]+/, ' '
    c.strip
  end

  def text_clean_par
    txt = ''
    self.css('>p').each{|p_node| txt << p_node.text_clean_br << "\n\n"}
    txt.gsub! /\s*\n\s*\n\s*/, "\n\n"
    txt.strip
  end
end


require 'addressable/uri'

module Recorder

  class Station
    attr_reader :name, :base_dir, :title, :program_url, :stream_url, :day_start, :timezone

    def initialize base_dir
      @base_dir = base_dir
      @name = File.basename @base_dir
      cfg_file = File.join(@base_dir, 'app','station.cfg')
      File.open(cfg_file, 'r' ) do |file|
        file.each_line do |line|
          case line
          when /title\s*=\s*'(.*)'/   then @title = $1
          when /program_url\s*=\s*'(.*)'/ then @program_url = Addressable::URI::parse($1)
          when /stream_url\s*=\s*'(.*)'/  then @stream_url = Addressable::URI::parse($1)
          when /day_start\s*=\s*'(\d{4})'/ then @day_start = $1
          when /timezone\s*=\s*'(.*)'/  then @timezone = $1
          end
        end
      end
      raise "'title' not found in #{cfg_file}"    if @title.nil?
      raise "'program_url' not found in #{cfg_file}"  if @program_url.nil?
      raise "'stream_url' not found in #{cfg_file}" if @stream_url.nil?
      raise "'day_start' not found in #{cfg_file}"  if @day_start.nil?
      raise "'timezone' not found in #{cfg_file}"   if @timezone.nil?
    end

    def curfew_for_day day
      m = /(\d{2})(\d{2})/.match self.day_start
      raise "Ouch" if m.nil?
      Time.local(day.year, day.month, day.day, m[1], m[2], 0).add_one_day
    end

    def day_start_for_day day
      m = /(\d{2})(\d{2})/.match self.day_start
      raise "Ouch" if m.nil?
      Time.local day.year, day.month, day.day, m[1], m[2], 0
    end
  end

  class Broadcast
    attr_reader :station, :dtstart, :title, :src_url
    attr_accessor :DC_language, :DC_copyright, :DC_title_series, :DC_title_episode, :DC_title, :DC_subject
    attr_accessor :DC_format_timestart, :DC_format_timeend, :DC_format_duration, :DC_description, :DC_image
    attr_accessor :DC_author, :DC_creator, :DC_publisher

    def initialize station, dtstart, title, src_url
      @station = station
      @dtstart = dtstart
      @title = title
      @src_url = src_url
    end

    def DC_format_timeend= t
      @DC_format_duration = (t - self.DC_format_timestart).to_i
      @DC_format_timeend = t
    end

    def to_s
      File.join station.name, '%04d' % dtstart.year, '%02d' % dtstart.month, '%02d' % dtstart.day, "#{dtstart.strftime '%H%M'} #{title}"
    end

    def exists?
      app_root = File.dirname(File.dirname(__FILE__))
      pat = File.join(app_root, 'stations', station.name, '%04d' % dtstart.year, '%02d' % dtstart.month, '%02d' % dtstart.day, "#{dtstart.strftime '%H%M'} *.xml")
      Dir.glob( pat ).length > 0
    end

    def kv_to_lua k,v,dst
      raise "key nil" if k.nil?
      return nil if v.nil?
      v = v.to_iso8601 if v.kind_of? Time
      v = v.to_s
      dst << "  #{k} = "
      dst << "'"
      dst << v.gsub("'", "\\\\'").gsub(/[\r\t ]*\n/, "\\n") # escape ' and \n
      dst << "',\n"
    end

    def to_lua dst,t_download_start=nil,t_scrape_start=nil,t_scrape_end=nil
      tmp = ''
      tmp << "-- comma separated lua tables, one per broadcast:\n"
      tmp << "{\n"
      kv_to_lua(:t_download_start, t_download_start.to_f, tmp) unless t_download_start.nil?
      kv_to_lua(:t_scrape_start, t_scrape_start.to_f, tmp) unless t_scrape_start.nil?
      kv_to_lua(:t_scrape_end, t_scrape_end.to_f, tmp) unless t_scrape_end.nil?

      kv_to_lua :station, station.name, tmp
      kv_to_lua :title, title, tmp
      kv_to_lua :DC_scheme, '/app/pbmi2003-recmod2012/', tmp
      kv_to_lua :DC_language, self.DC_language, tmp
      kv_to_lua(:DC_title, self.DC_title.nil? ? title : self.DC_title, tmp)
      kv_to_lua :DC_title_series, self.DC_title_series, tmp
      kv_to_lua :DC_title_episode, self.DC_title_episode, tmp
      kv_to_lua :DC_subject, self.DC_subject, tmp
      kv_to_lua(:DC_format_timestart, self.DC_format_timestart.nil? ? dtstart : self.DC_format_timestart, tmp)
      kv_to_lua :DC_format_timeend, self.DC_format_timeend, tmp
      kv_to_lua :DC_format_duration, self.DC_format_duration, tmp
      kv_to_lua :DC_image, self.DC_image, tmp
      kv_to_lua :DC_description, self.DC_description, tmp
      kv_to_lua :DC_author, self.DC_author, tmp
      kv_to_lua :DC_publisher, self.DC_publisher, tmp
      kv_to_lua :DC_creator, self.DC_creator, tmp
      kv_to_lua :DC_copyright, self.DC_copyright, tmp
      kv_to_lua :DC_source, self.src_url, tmp
      tmp << "},\n"
      tmp << "\n"
      dst << tmp
    end
  end

  class Scraper
    attr_reader :station

    def initialize station
      @station = station
    end

    def self.clean s
      r = s.gsub(/\s+/, ' ')
      r.strip!
      r
    end

    def update_broadcasts_between tmin, tmax, force
      raise 'overload me!'
    end
  end
end


###############################################################################
##  the actual commandline script interface impl.
###############################################################################
require 'getoptlong'
require 'peach'

module Recorder
  class Scraper
    def run_update_broadcast
      opts = GetoptLong.new(
        [ "--verbose", "-v",      GetoptLong::NO_ARGUMENT ],
        [ "--help",  "-h",  '-?', GetoptLong::NO_ARGUMENT ],
        [ '--new',      GetoptLong::NO_ARGUMENT ],
        [ '--total',      GetoptLong::NO_ARGUMENT ],
        [ '--future',     GetoptLong::NO_ARGUMENT ],
        [ '--incremental',  GetoptLong::NO_ARGUMENT ]
      )
      mode = :incremental
      verbose = false
      begin
        opts.each do |opt, arg|
          mode     = :new if opt == '--new'
          mode     = :future if opt == '--future'
          mode     = :total if opt == '--total'
          mode     = :incremental if opt == '--incremental'
          verbose = true if opt == '--verbose'
          display_updatebroadcast_help if opt == '--help'
        end
        display_updatebroadcast_help if opts.error?
      rescue GetoptLong::InvalidOption => e
        display_updatebroadcast_help if opts.error?
      end

      if ARGV.count == 0
        case mode
        when :new
          self.update_broadcasts_between Time.at(0), Time.now + 10*365*24*60*60, false
        when :total
          self.update_broadcasts_between Time.at(0), Time.now + 10*365*24*60*60, true
        when :future
          self.update_broadcasts_between Time.now, Time.now + 10*365*24*60*60, true
        when :incremental
          [0, 12, 3*24, 7*24, 49*24].collect{|dt| Time.now.localtime + dt*60*60}.peach(4) do |tmin|
            self.update_broadcasts_between tmin, tmin + 65 * 60, true
          end
        else
          display_updatebroadcast_help if opts.error?
        end
      else
        display_updatebroadcast_help if opts.error?
      end
    end


    def display_updatebroadcast_help
      s = <<END_OF_HELP
Rescrape broadcasts.

  --new         all missing broadcasts
  --total       all broadcasts
  --future      all future broadcasts
  --incremental next hour, next hour tomorrow, +1 week
  -? --help
  -v --verbose

END_OF_HELP
      $stderr.puts s
      exit 0
    end
  end
end
