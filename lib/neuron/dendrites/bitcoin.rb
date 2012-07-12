#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'httparty'

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
      if message["type"] == "emessage" && message["command"] == "PRIVMSG"
        expr = message["message"].match(/^bitcoin\s?(.*)/)
        if expr
          puts "loading mtgox"
          ticker = HTTParty.get("https://mtgox.com/api/0/data/ticker.php",
                                :headers => {"user-agent"=>"neuroirc"})
          if ticker
            msg = "Bitcoin report - last $#{ticker["ticker"]["last"]}(mtgox). 24hr volume #{ticker["ticker"]["vol"]} btc"
          else
            msg = "mtgox api fail."
          end
          if message["to_me"] == "true"
            msg = "#{message["nick"]}: "+msg
          end
          predis.publish :say, {"command" => "say",
                                "target" => message["target"],
                                "message" => msg}.to_json
        end
      end
    end
  end

