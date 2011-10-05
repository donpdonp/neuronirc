#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'faraday'

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
        expr = message["message"].match(/^!?(quote|stock)\s+(.+)/)
        if expr
          symbol = expr[2]
          url = "http://download.finance.yahoo.com/d/quotes.csv?s=#{symbol}&f=snl1"
          puts "Searching for stock symbol #{symbol}; #{url}"
          csv = Faraday.get url
          msg = csv.body.split(',')
          msg = "#{msg[0].gsub('"','')} #{msg[1]} $#{msg[2]}"
          if message["to_me"] == "true"
            msg = "#{message["nick"]}: #{msg}"
          end

          predis.publish :say, {"command" => "say", 
                                "target" => message["target"], 
                                "message" => msg}.to_json unless csv.nil?
        end
      end
    end
  end

