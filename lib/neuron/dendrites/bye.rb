#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'neuron/dendrite'

STDOUT.sync = true

class Bye
  include Neuron::Dendrite

  def go
    setup
    bye_rex = /^(bye|bye bye|bye-bye|goodbye|good-bye|see ya|so long|later)[!\.]?$/
    puts "Looking for byes with #{bye_rex}"

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
            if message["message"].match(bye_rex)
              puts "Saying hi"
              if message["to_me"] == "true"
                msg = "#{message["nick"]}: Bye bye."
              else
                msg = "See ya, #{message["nick"]}."
              end
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

Bye.new.go
