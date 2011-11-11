#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'neuron/dendrite'
require 'httparty'


STDOUT.sync = true

class Iss
  include Neuron::Dendrite

  def go
    setup
    redis = Redis.new
    Thread.new do 
      puts "ISS watch thread started"
      loop do
        min_left = (next_pass["risetime"] - Time.now)/60
        if min_left < 64 && min_left >= 60
          msg = "ISS visible for #{"%0.2f" % next_pass["duration"]/60.0}min starting at #{next_pass["risetime"]}"
          @redis.publish :say, {"command" => "say",
                                "target" => '#pdxbots',
                                "message" => msg}.to_json
        else
          msg = "min_left #{min_left}"
        end
        sleep 300
      end
    end

    redis.subscribe(:lines) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, json|
        message = JSON.parse(json)
        if message["target"][0] == '#' && message["type"] == "emessage" && message["to_me"] == "true"
          expr = message["message"].match(/iss/)
          if expr
            msg = "#{message["nick"]}: next pass #{next_pass}"
            @redis.publish :say, {"command" => "say",
                                  "target" => message["target"],
                                  "message" => msg}.to_json
          end
        end
      end
    end
  end

  def next_pass
    passes = HTTParty.get("http://api.open-notify.org/iss/?lat=45&lon=-122")
    pass = passes["response"].first
    pass["risetime"] = Time.at(pass["risetime"])
    return pass
  end
end

Iss.new.go
