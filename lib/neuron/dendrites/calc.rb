#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'httparty'
require 'nokogiri'

STDOUT.sync = true
BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__),"."))
SETTINGS = JSON.load(File.open(File.join(BASE_DIR,"../../../settings.json")))

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
      if message["target"] && message["target"][0] == '#' && message.has_key?("type") && message["type"] == "emessage"
        expr = message["message"].match(/!?calc\s+([0-9\.\^*+-\/()^<>= ]+)/)
        if expr
          answer = eval expr[1] rescue nil
          puts "Calculating #{expr} to #{answer}"
          msg = "#{expr[1]} == #{answer}"
          if message["to_me"] == "true"
            msg = "#{message["nick"]}: "+msg
          end
          predis.publish :say, {"command" => "say",
                                "target" => message["target"],
                                "message" => msg}.to_json unless answer.nil?
        end

        solve = message["message"].match(/!?solve\s+(.*)/)
        if solve && solve.captures.size > 0
          query = solve.captures[0]
          puts "Wolfram Alpha query: #{query}"
          answer = HTTParty.get "http://api.wolframalpha.com/v2/query",
                      :query => {"input" => query,
                                 "appid" => SETTINGS['wolfram']['appid']}
          xml = Nokogiri::XML(answer.body)
          result = xml.xpath("/queryresult/pod[@title='Result']/subpod/plaintext")
          eresult = xml.xpath("/queryresult/pod[@title='Mixed fraction']/subpod/plaintext")
          solution = xml.xpath("/queryresult/pod[@title='Solution']/subpod/plaintext")
          average = xml.xpath("/queryresult/pod[@title='Average result']/subpod/plaintext")
          answer = "#{result.text}#{eresult.text}#{solution.text}#{average.text}"
          if answer.blank?
            msg = "cant say"
          else
            msg = answer
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

