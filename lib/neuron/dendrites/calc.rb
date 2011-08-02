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
        expr = message["message"].match(/!calc\s+(.*)/)
        if expr
          expr = expr[1].gsub(/[^0-9\.\^*+-\/() ]/,'')
          answer = eval expr rescue nil
          puts "Calculating #{expr} to #{answer}"
          nick = message["name"].match(/(.*)!/)[1]
          predis.publish :say, {"command" => "say", "target" => message["target"], "message" => "#{expr} == #{answer}"}.to_json unless answer.nil?
        end
      end
    end
  end

