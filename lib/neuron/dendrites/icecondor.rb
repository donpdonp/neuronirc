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
          puts "IceCondor connected. #{event.data.inspect}"
        end
        ws.onmessage = lambda do |event|
          puts "event.data = #{event.data}"
          msg = JSON.parse(event.data)
          puts "msg = #{msg}"
          if msg["type"] == "hello"
            puts "got hello in onmessage. following #{username}"
            ws.send({"type"=>"follow","username"=>username}.to_json)
          end
          if msg["type"] == "location"
            msg.merge!({"type" => "location"})
            @redis.publish :lines, msg.to_json
          end
        end
      end
    end
  end
end

IceCondor.new.go
