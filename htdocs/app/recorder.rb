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


require 'uri'

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
                    when /title\s*=\s*'(.*)'/       then @title = $1
                    when /program_url\s*=\s*'(.*)'/ then @program_url = URI::parse($1)
                    when /stream_url\s*=\s*'(.*)'/  then @stream_url = URI::parse($1)
                    when /day_start\s*=\s*'(\d{4})'/ then @day_start = $1
                    when /timezone\s*=\s*'(.*)'/    then @timezone = $1
                    end
                end
            end
            raise "'title' not found in #{cfg_file}"        if @title.nil?
            raise "'program_url' not found in #{cfg_file}"  if @program_url.nil?
            raise "'stream_url' not found in #{cfg_file}"   if @stream_url.nil?
            raise "'day_start' not found in #{cfg_file}"    if @day_start.nil?
            raise "'timezone' not found in #{cfg_file}"     if @timezone.nil?
        end

        def day_start_for_day day
            m = /(\d{2})(\d{2})/.match self.day_start
            raise "Ouch" if m.nil?
            Time.local day.year, day.month, day.day, m[1], m[2], 0
        end
    end

    class Broadcast
        attr_reader :station, :dtstart, :title, :src_url
        attr_accessor :DC_language, :DC_author, :DC_copyright, :DC_title_series, :DC_title_episode, :DC_title
        attr_accessor :DC_format_timestart, :DC_format_timeend, :DC_format_duration, :DC_description, :DC_image
        attr_accessor :DC_creator, :DC_publisher

        def initialize station, dtstart, title, src_url
            @station = station
            @dtstart = dtstart
            @title = title
            @src_url = src_url
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
            dst << '  ' << k << " = "
            dst << "'"
            dst << v.gsub("'", "\\\\'").gsub(/\n/, "\\n") # escape ' and \n
            dst << "',\n"
        end

        def to_lua dst,t_download_start=nil,t_scrape_start=nil,t_scrape_end=nil
            dst << "-- comma separated lua tables, one per broadcast:\n"
            dst << "{\n"
            kv_to_lua(:t_download_start, t_download_start.to_f, dst) unless t_download_start.nil?
            kv_to_lua(:t_scrape_start, t_scrape_start.to_f, dst) unless t_scrape_start.nil?
            kv_to_lua(:t_scrape_end, t_scrape_end.to_f, dst) unless t_scrape_end.nil?

            kv_to_lua :station, station.name, dst
            kv_to_lua :title, title, dst
            kv_to_lua :DC_scheme, '/app/pbmi2003-recmod2012/', dst
            kv_to_lua :DC_language, self.DC_language, dst
            kv_to_lua(:DC_title, self.DC_title.nil? ? title : self.DC_title, dst)
            kv_to_lua :DC_title_series, self.DC_title_series, dst
            kv_to_lua :DC_title_episode, self.DC_title_episode, dst
            kv_to_lua(:DC_format_timestart, self.DC_format_timestart.nil? ? dtstart : self.DC_format_timestart, dst)
            kv_to_lua :DC_format_timeend, self.DC_format_timeend, dst
            kv_to_lua :DC_format_duration, self.DC_format_duration, dst
            kv_to_lua :DC_image, self.DC_image, dst
            kv_to_lua :DC_description, self.DC_description, dst
            kv_to_lua :DC_publisher, self.DC_publisher, dst
            kv_to_lua :DC_creator, self.DC_creator, dst
            kv_to_lua :DC_copyright, self.DC_copyright, dst
            kv_to_lua :DC_source, self.src_url, dst
            dst << "},\n"
            dst << "\n"
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

module Recorder
    class Scraper
        def run_update_broadcast
            opts = GetoptLong.new(
              [ "--verbose", "-v",        GetoptLong::NO_ARGUMENT ],
              [ "--help",    "-h",  '-?', GetoptLong::NO_ARGUMENT ],
              [ '--new',            GetoptLong::NO_ARGUMENT ],
              [ '--total',          GetoptLong::NO_ARGUMENT ],
              [ '--future',         GetoptLong::NO_ARGUMENT ],
              [ '--incremental',    GetoptLong::NO_ARGUMENT ]
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
                    # rescrape next hour
                    tmin = Time.now.localtime
                    self.update_broadcasts_between tmin, tmin + 65 * 60, true
                    # rescrape next hour tomorrow
                    tmin = Time.now.localtime + 1*24*60*60 + 5*60
                    self.update_broadcasts_between tmin, tmin + 65 * 60, true
                    # rescrape next hour seven days ahead
                    tmin = Time.now.localtime + 7*24*60*60 + 5*60
                    self.update_broadcasts_between tmin, tmin + 65 * 60, true
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

    --new           all missing broadcasts
    --total         all broadcasts
    --future        all future broadcasts
    --incremental   next hour, next hour tomorrow, +1 week
    -? --help
    -v --verbose

END_OF_HELP
            $stderr.puts s
            exit 0
        end
    end
end
