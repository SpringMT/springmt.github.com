#!/usr/bin/env ruby
# encoding: UTF-8

require 'pp'
require 'mysql2'
require 'thread'

#client = Mysql2::Client.new(:host => "localhost", :username => "root")

thread = []
@t = 0
10.times do |n|
  thread << Thread.new{
    @t += 1
    num = @t
    print "#{num} start \n"
    client = Mysql2::Client.new(:host => "localhost", :username => "root")
    client.query("SELECT sleep(1)", async: false)
    print "#{num} end \n"
  }
end

thread.each {|t| t.join}
