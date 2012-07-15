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
  end
end