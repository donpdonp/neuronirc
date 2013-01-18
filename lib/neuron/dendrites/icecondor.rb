require 'neuron/dendrite'

class IceCondor
  include Neuron::Dendrite

  def go
    on_message do |channel, message|
      puts "icecondor! #{message}"
    end
  end
end

IceCondor.new.go
