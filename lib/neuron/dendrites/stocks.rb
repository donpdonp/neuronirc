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
      if message["type"] == "emessage" && message["target"] && message["target"][0] == '#'
        expr = message["message"].match(/^!?(quote|stock)\s+(.+)/)
        if expr
          symbol = expr[2]
          puts "Searching YQL for stock symbol #{symbol}"
          csv = Faraday.get do|r|
            r.url "http://query.yahooapis.com/v1/public/yql",
            :q=>"select * from yahoo.finance.quotes where symbol in (#{symbol.to_json})",
            :env=>'http://datatables.org/alltables.env',
            :format=>'json'
          end
          msg = ""
          response=JSON.parse(csv.body)
          puts response.inspect
          if response["query"]["results"]
            q = response["query"]["results"]["quote"]
            msg += ["#{q["Symbol"]} \"#{q["Name"]}\"",
                    "open: $#{q["Open"]}",
                    "last: $#{q["LastTradePriceOnly"]}",
                    "P/E: #{q["PERatio"]}",
                    "market cap: $#{q["MarketCapitalization"]}",
                    "(#{q["StockExchange"]})"
                   ].join(' ')
            if message["to_me"] == "true"
              msg = "#{message["nick"]}: #{msg}"
            end
          else
            msg = "yahoo choked: #{response.inspect}"
          end
          predis.publish :say, {"command" => "say",
                                "target" => message["target"],
                                "message" => msg}.to_json unless csv.nil?
        end
      end
    end
  end

