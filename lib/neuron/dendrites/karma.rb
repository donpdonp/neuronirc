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
      if message["target"][0] == '#' && message["type"] == "emessage" && message["to_me"] == "true"
        expr = message["message"].match(/!?karma ?(\w+)?/)
        if expr
          count = expr[1] ? expr[1].to_i : 1
          count.times do
            msg = "#{message["nick"]}++"
            predis.publish :say, {"command" => "say", 
                                  "target" => message["target"], 
                                  "message" => msg}.to_json
          end
        end
      end
    end
  end

