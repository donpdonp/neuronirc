#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'neuron/dendrite'

STDOUT.sync = true

class Hello
  include Neuron::Dendrite

  def go
    setup
    hello_rex = /^(#{mynick}:\s*)?(hello|hi|howdy)[!\.]?$/
    puts "Looking for hellos to #{mynick} with #{hello_rex}"
    redis = Redis.new
    redis.subscribe(:lines) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, json|
        message = JSON.parse(json)
        puts "Heard #{message}"
        if message["target"][0] == '#'
          if message["message"].match(hello_rex)
            puts "Saying hi"
            nick = message["name"].match(/(.*)!/)[1]
            @redis.publish :say, {"command" => "say", "target" => message["target"], "message" => "Hello #{nick}. I am a bot."}.to_json
          end
        end
      end
    end
  end
end

Hello.new.go
