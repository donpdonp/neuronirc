require 'neuron/dendrite'
require 'faye/websocket'

STDOUT.sync = true

class IceCondor
  include Neuron::Dendrite

  def go
    EventMachine.run do
      uri = "wss://api.icecondor.com"
      puts "IceCondor connecting #{uri}"
      ws = Faye::WebSocket::Client.new(uri)
      ws.onopen = lambda do |event|

      end
      ws.onmessage = lambda do |event|
        puts event.data
      end
    end

    on_message do |channel, message|
      puts "#{message}"
    end
  end
end

IceCondor.new.go
