#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'

  redis = Redis.new
  predis = Redis.new
  redis.subscribe(:lines) do |on|
    on.subscribe do |channel, subscriptions|
      puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
    end
    on.message do |channel, json|
      message = JSON.parse(json)
      puts "Heard #{message}"
      if message["target"][0] == '#'
        if message["message"].match(/zrobo:.*(goodbye|bye)/)
          puts "Saying bye"
          predis.publish :say, {"target" => message["target"], "message" => "Bye-bye #{message["name"]}"}.to_json
        end
      end
    end
  end

