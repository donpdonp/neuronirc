#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'neuron/dendrite'

STDOUT.sync = true

class Semantic
  include Neuron::Dendrite

  def go
    setup
    redis = Redis.new
    redis.subscribe(:lines) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, json|
        message = JSON.parse(json)
        if message["type"].nil?
          to_me_rex = /^\s*#{mynick}:?\s+(.*)/
          to_me_mat = message["message"].match(to_me_rex)
          if to_me_mat
            text = to_me_mat[1]
            to_me = true
          else
            text = message["message"]
          end
          nick = message["name"].match(/(.*)!/)[1]
          message.merge!({"type" => "emessage", 
                          "nick" => nick, 
                          "to_me" => to_me ? "true" : "false", 
                          "message" => text})
          puts "Repackaged #{message}"
          @redis.publish :lines, message.to_json
        end
      end
    end
  end
end

Semantic.new.go
