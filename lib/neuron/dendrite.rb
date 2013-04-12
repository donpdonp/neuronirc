require 'redis'
require 'json'

module Neuron
  module Dendrite
    def setup
      @redis = Redis.new
    end

    def mynick
      @redis.get('nick')
    end

    def say(target, msg)
      @redis.publish :say, {"command" => "say",
                            "target" => target,
                            "message" => msg}.to_json
      puts "Saying #{target} #{msg}"
    end

    def emit(opts)
      puts "Emitting #{opts.inspect}"
      @redis.publish :lines, opts.to_json
    end

    def on_message(&blk)
      redis = Redis.new
      redis.subscribe(:lines) do |on|
        on.subscribe do |channel, subscriptions|
          puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end
        on.message do |channel, json|
          message = JSON.parse(json)
          yield channel, message
        end
      end
    end
  end
end