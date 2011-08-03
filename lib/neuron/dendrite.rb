module Neuron
  module Dendrite
    def setup
      @redis = Redis.new
    end

    def mynick
      @redis.get('nick')
    end
  end
end