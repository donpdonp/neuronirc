require 'neuron/dendrite'
require 'faye/websocket'

STDOUT.sync = true

class IceCondor
  include Neuron::Dendrite

  def go
    user_follow_thread = location_follow('donpdonp')
    on_message do |channel, message|
      puts "#{message}"
    end
  end

  def location_follow(username)
    Thread.new do
      EventMachine.run do
        uri = "wss://api.icecondor.com"
        puts "IceCondor connecting #{uri}"
        ws = Faye::WebSocket::Client.new(uri)
        ws.onopen = lambda do |event|
          puts "following #{username}"
          ws.send({"type"=>"follow","username"=>username}.to_json)
        end
        ws.onmessage = lambda do |event|
          puts event.data
        end
      end
    end
  end
end

IceCondor.new.go
