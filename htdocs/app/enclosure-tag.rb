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

HELP_TEXT = <<END_OF_HELP

Usage:
  app/enclosure-tag.rb enclosure0.mp3 enclosure1.mp3 enclosure1.mp3

tags the given enclosures with meta data from it's broadcast file (xml).

END_OF_HELP


if ARGV.count == 0 || ARGV[0] == '--help' || ARGV[0] == '-?'
  $stderr.puts HELP_TEXT
end

require 'uri'
require 'open-uri'
require 'rubygems'
require 'taglib'  # gem 'taglib-ruby', '= 0.4.0', :require => 'taglib'

def xml_for_mp3 mp3
  m = /([^\/]+\/\d{4}\/\d{2}\/\d{2}\/\d{4}\s.*)\.mp3$/.match mp3
  raise "Ouch" if m.nil?
  File.join 'stations', m[1] + ".xml"
end

require 'rexml/document'

def unescape_attr s
  # http://www.ruby-forum.com/topic/159283#701331
  REXML::Text::unnormalize(s)
end

def meta_from_xml xml
  ret = {}
  File.open(xml, 'r') do |f|
    pat = /<meta content='([^']*)' name='(DC\.[^']*)'\s*\/?>/
    f.each_line do |l|
      m = pat.match l
      ret[ m[2].tr('.','_').intern ] = unescape_attr(m[1]) unless m.nil?
    end
  end
  ret
end

def tag_mp3 enclosure_file_path, dc_meta
  m = /([^\/]+)\/(\d{4})\/\d{2}\/\d{2}\/\d{4}\s.*\.mp3$/.match enclosure_file_path
  raise "aua!" if m.nil?
  TagLib::MPEG::File.open(enclosure_file_path) do |file|
    file.strip # remove old data

    tag = file.id3v2_tag(true) # create tag
    tag.title = dc_meta[:DC_title]
    tag.artist = "Station #{m[1]}"
    tag.album = dc_meta[:DC_title_series] unless dc_meta[:DC_title_series].nil?
    tag.genre = 'Radio'
    tag.year = m[2].to_i

    txt = '' << enclosure_file_path << "\n"
    txt <<= dc_meta[:DC_source] << "\n\n"
    txt <<= dc_meta[:DC_title_series] << "\n\n" unless dc_meta[:DC_title_series].nil? || dc_meta[:DC_title_series].length == 0
    txt <<= dc_meta[:DC_title_episode] << "\n\n" unless dc_meta[:DC_title_episode].nil? || dc_meta[:DC_title_episode].length == 0
    txt <<= dc_meta[:DC_description]

    comm = TagLib::ID3v2::CommentsFrame.new('COMM')
    comm.text = txt
    comm.language = 'de'
    comm.text_encoding = TagLib::String::UTF8
    tag.add_frame(comm)

    # duplicate into lyrics, as iTunes purges the comment:
    lyr = TagLib::ID3v2::UnsynchronizedLyricsFrame.new
    lyr.text = txt
    lyr.language = 'de'
    lyr.text_encoding = TagLib::String::UTF8
    tag.add_frame(lyr)

    unless dc_meta[:DC_image].nil?
      img_uri = URI::parse dc_meta[:DC_image]
      picture = TagLib::ID3v2::AttachedPictureFrame.new
      picture.mime_type = "image/jpeg"
      # picture.description = "Cover"
      picture.type = TagLib::ID3v2::AttachedPictureFrame::FrontCover
      picture.picture = img_uri.read
      tag.add_frame(picture)
    end
    file.save
  end
end

Dir.chdir File.dirname(File.dirname(__FILE__))

ARGV.each do |mp3|
  begin
    $stderr.puts "tagging #{mp3}"
    tag_mp3 mp3, meta_from_xml(xml_for_mp3(mp3))
  rescue Exception => e
    $stderr.puts "error #{e}"
  end
end
