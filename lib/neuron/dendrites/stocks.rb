#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'faraday'
require 'csv'

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
          puts "Searching for stock symbol #{symbol}"
          csv = Faraday.get {|r| r.url "http://download.finance.yahoo.com/d/quotes", :symbol=>symbol, :f => "snl1"}
          msg = ""
          CSV.parse(csv.body) do |row|
            if row[2].to_i > 0
              msg += "#{row[0]} #{row[1]} $#{row[2]} "
            else
              msg += "#{row[0]}: nothing"
            end
          end
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

