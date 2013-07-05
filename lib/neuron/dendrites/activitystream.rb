require 'neuron/dendrite'
require 'rethinkdb'

STDOUT.sync = true

class ActivityStream
  include Neuron::Dendrite

  def go
    setup
    on_message do |channel, message|
      if message["command"] == "PRIVMSG" && message["type"] == "emessage"
        match = message["message"].match(/^icecondor (\w+) ?(.*)?$/)
        if match
          dispatch(message)
        end
      end
    end
  end
end

ActivityStream.new.go
