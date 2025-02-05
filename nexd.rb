#!/usr/bin/env ruby
#
# This is a little Nightfall Express server for everyone to enjoy.
#
# This code is dedicated to the public domain for the benefit of the
# community at large, and to the detriment of the original author (Charlotte
# Koch: dressupgeekout@gmail.com).
#
# Usage:
#
#   $ ruby nexd.rb [-d,--docroot PATH] [-p,--port PORT]
#
# The default docroot is './docroot'.
# The default port number is 1900.
#
# "Ride the sainted rhythms on the midnight train to Romford."
#

require 'optparse'
require 'socket'

########## ########## ##########

# Common constants.
module Nex
  DEFAULT_PORT = 1900
  DEFAULT_DOCROOT = File.expand_path("./docroot")
end

########## ########## ##########

class Nexd
  attr_accessor :client

  def initialize(**kwargs)
    @port = kwargs[:port] || Nex::DEFAULT_PORT
    @docroot = kwargs[:docroot] || Nex::DEFAULT_DOCROOT
    @server = TCPServer.new(@port)
    @client = nil
  end

  # Returns a string that lists the contents of the given directory. Includes
  # a trailing slash for entries that are themselves directories.
  def dirlisting(dir)
    list = []
    Dir.entries(dir).each do |entry|
      next if entry == "."
      item = "=> #{entry}"
      item += "/" if File.directory?(File.join(dir, entry))
      list << item
    end
    return list.sort.join("\n") + "\n"
  end

  # Writes a timestamped message to stdout.
  def log(str)
    puts "#{Time.now}\t#{str}"
  end

  # Sanity checks before showtime.
  def preflight
    ok = true

    if !File.directory?(@docroot)
      $stderr.puts("FATAL: no such directory: #{@docroot}")
      ok = false
    end

    if ok
      return nil
    else
      return 1
    end
  end

  # This is a very simple server that blocks for the next connection; it can
  # service only 1 client at a time. 
  def main
    rv = self.preflight
    return rv if rv

    puts "-- nexd.rb listening on port #{@port.to_s} --"
    puts "-- Serving files from #{@docroot} --"

    loop do
      @client = @server.accept

      reqline = @client.gets

      if !reqline
        log("ERROR\tno reqline?")
        @client.close
        next
      end

      reqline.chomp!
      log("REQUEST\t#{reqline}")

      reqd_file = File.join(@docroot, reqline)

      if File.directory?(reqd_file)
        @client.write(dirlisting(reqd_file))
        @client.close
        next
      elsif !File.file?(reqd_file)
        @client.write("Sorry, no such resource: #{reqline}\n")
        @client.close
        next
      end

      @client.write(File.read(reqd_file))
      @client.close
    end

    return 0
  end
end

########## ########## ##########

if $0 == __FILE__
  # Parse command-line options.
  port = nil
  docroot = nil

  parser = OptionParser.new do |opts|
    opts.on("-p", "--port NUMBER") { |port| port = port.to_i }
    opts.on("-d", "--docroot PATH") { |d| docroot = File.expand_path(d) }
  end
  parser.parse!(ARGV)

  # Ready to roll.
  nexd = Nexd.new(:port => port, :docroot => docroot)

  trap("INT") do
    puts "\n-- SIGINT received, quitting. --"
    nexd.client.close
    exit 0
  end

  rv = nexd.main
  exit rv
end
