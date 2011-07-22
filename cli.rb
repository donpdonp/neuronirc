#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'

redis = Redis.new

exit if ARGV.size == 0

if ARGV.size == 2
  msg = {"command" => ARGV[0], "message" => ARGV[1]}
end

if ARGV[0] == "say"
  msg = {"command" => ARGV[0], "target" => ARGV[1], "message" => ARGV[2]}
end

puts msg.inspect
redis.publish :say, msg.to_json
