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
      if message["target"] && message["target"][0] == '#' && message.has_key?("type") && message["type"] == "emessage"
        expr = message["message"].match(/^\s*(\(?[-+]?[0-9]*\.?[0-9]+[\^*+\-\/() ]+[\^*+\-\/() 0-9\.]+)\s*$/)
        if expr
          begin
            formula = expr[1]
            puts "Calculating #{formula}"
            answer = eval("1.0*#{formula}")
            msg = "#{formula} == #{answer}"
            if message["to_me"] == "true"
              msg = "#{message["nick"]}: "+msg
            end
          rescue Exception => e
            puts "caught #{e}"
            msg = e.to_s.match(/syntax error/) ? nil : "#{formula} : #{e}"
          end
          predis.publish :say, {"command" => "say",
                                "target" => message["target"],
                                "message" => msg}.to_json
        end

        solve = message["message"].match(/^\s*!?solve\s+(.*)/)
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
          if answer.empty?
            msg = "there is no easy answer to \"#{query}\""
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

