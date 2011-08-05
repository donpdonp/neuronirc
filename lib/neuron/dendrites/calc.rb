#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'

  STDOUT.sync = true
  redis = Redis.new
  predis = Redis.new
  redis.subscribe(:lines) do |on|
    on.subscribe do |channel, subscriptions|
      puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
    end
    on.message do |channel, json|
      message = JSON.parse(json)
      puts "Heard #{message}"
      if message["target"][0] == '#' && message["type"] == "emessage"
        expr = message["message"].match(/!?calc\s+(.*)/)
        if expr
          expr = expr[1].gsub(/[^0-9\.\^*+-\/()!^<>= ]/,'')
          answer = eval expr rescue nil
          puts "Calculating #{expr} to #{answer}"
          msg = "#{expr} == #{answer}"
          if message["to_me"] == "true"
            msg = "#{message["nick"]}: "+msg
          end
          predis.publish :say, {"command" => "say", 
                                "target" => message["target"], 
                                "message" => msg}.to_json unless answer.nil?
        end
      end
    end
  end

