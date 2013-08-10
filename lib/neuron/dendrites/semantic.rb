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
        if message["type"].nil? && message["command"] == "PRIVMSG"
          to_me_rex = /^(\s*(\w+):\s*)?(.*)/
          to_me_mat = message["message"].match(to_me_rex)
          if to_me_mat
            text = to_me_mat[3]
            to_nick = to_me_mat[2]
            if to_nick == mynick
              to_me = true
            end
          else
            text = message["message"]
          end
          nick = message["name"].match(/(.*)!/)[1]
          message.merge!({"type" => "emessage",
                          "nick" => nick,
                          "to_nick" => to_nick,
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
