require 'neuron/dendrite'
require 'faye/websocket'

STDOUT.sync = true

class IceCondor
  include Neuron::Dendrite

  def initialize
    @follow_threads = {}
  end

  def go
    setup
    on_message do |channel, message|
      if message["command"] == "PRIVMSG" && message["type"] == "emessage"
        match = message["message"].match(/^icecondor (\w+) ?(.*)?$/)
        if match
          cmd, after = match[1], match[2]
          puts "icecondor #{cmd} #{after}"
          dispatch(cmd, after, message)
        end
      end
    end
  end

  def dispatch(command, after, message)
    if command == "track"
      username = after
      if @follow_threads[username]
        say(message["target"], "already following #{username}")
      else
        @follow_threads[username] = location_follow(username)
        say(message["target"], "tracking started for #{username}")
      end
    end
    if command == "stop"
      username = after
      if @follow_threads[username]
        Thread.kill @follow_threads[username]
        @follow_threads.delete(username)
        say(message["target"], "stopped track of #{username}")
      else
        say(message["target"], "not tracking #{username}")
      end
    end
    if command == "list"
      say(message["target"], "tracking #{@follow_threads.keys}")
    end
    if command == "help"
      say(message["target"], "icecondor: track <username>, list, stop <username>")
    end
  end

  def location_follow(username)
    redis = Redis.new
    Thread.new do
      EventMachine.run do
        uri = "wss://api.icecondor.com"
        puts "IceCondor connecting #{uri}"
        ws = Faye::WebSocket::Client.new(uri)
        ws.onopen = lambda do |event|
          puts "IceCondor connected."
        end
        ws.onmessage = lambda do |event|
          msg = JSON.parse(event.data)
          puts "ws: #{msg}"
          if msg["type"] == "hello"
            puts "got hello. following #{username}"
            ws.send({"type"=>"follow","username"=>username}.to_json)
          end
          if msg["type"] == "location"
            msg.merge!({"type" => "location"})
            puts "publish: #{msg}"
            redis.publish :lines, msg.to_json
          end
        end
        ws.onclose = lambda do |event|
          p [:close, event.code, event.reason]
          puts "websocket closed for #{username}"
        end
      end
      puts "Eventmachine.run ended"
    end
  end
end

IceCondor.new.go
