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
        if message["message"].match(/(zrobo:\s*)?(hello|hi)\.?$/)
          puts "Saying hi"
          nick = message["name"].match(/(.*)!/)[1]
          predis.publish :say, {"command" => "say", "target" => message["target"], "message" => "Hello #{nick}. I am a bot."}.to_json
        end
      end
    end
  end

