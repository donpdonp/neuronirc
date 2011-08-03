#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'neuron/dendrite'

STDOUT.sync = true

class Hello
  include Neuron::Dendrite

  def go
    setup
    hello_rex = /^(hello|hi|howdy)[!\.]?$/
    puts "Looking for hellos with #{hello_rex}"

    redis = Redis.new
    redis.subscribe(:lines) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, json|
        message = JSON.parse(json)
        puts "Heard #{message}"
        if message["type"] == "emessage"
          if message["target"][0] == '#'
            if message["message"].match(hello_rex)
              puts "Saying hi"
              if message["to_me"] == "true"
                msg = "#{message["nick"]}: Hello."
              else
                msg = "Hello #{message["nick"]}."
              end
              msg += " I am a bot."
              @redis.publish :say, {"command" => "say", 
                                    "target" => message["target"],
                                    "message" => msg}.to_json
            end
          end
        end
      end
    end
  end
end

Hello.new.go
