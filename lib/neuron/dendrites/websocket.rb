require 'neuron/dendrite'
require 'faye/websocket'

STDOUT.sync = true

class Neuron::WebSocket
  include Neuron::Dendrite

  def initialize
    @follow_threads = {}
  end

  def go
    setup
    on_message do |channel, message|
      if message["command"] == "PRIVMSG" && message["type"] == "emessage"
        match = message["message"].match(/^websocket (\w+) ?(.*)?$/)
        if match
          cmd, after = match[1], match[2]
          puts "websocket #{cmd} #{after}"
          dispatch(cmd, after, message)
        end
      end
      if message["type"] == "websocket" && !message["command"] == "control"
        dispatch(message["command"], message["url"], message)
      end
    end
  end

  def dispatch(command, url, message)
    if command == "open"
      if @follow_threads[url]
        if(message["target"])
          say(message["target"], "already monitoring #{url}")
        end
      else
        @follow_threads[url] = open(url)
        if(message["target"])
          say(message["target"], "monitoring websocket #{url}")
        end
      end
    end
    if command == "close"
      if @follow_threads[url]
        Thread.kill @follow_threads[url]
        @follow_threads.delete(url)
        say(message["target"], "stopped monitoring of #{url}")
      else
        say(message["target"], "not monitoring #{url}")
      end
    end
    if command == "list"
      if @follow_threads.keys.empty?
        msg = "not monitoring any websockets at this time"
      else
        msg = "monitoring #{@follow_threads.keys.join(', ')}"
      end
      say(message["target"], msg)
    end
    if command == "help"
      say(message["target"], "websocket: open <url>, list, close <url>")
    end
  end

  def open(url)
    redis = Redis.new
    Thread.new do
      EventMachine.run do
        puts "opening #{url}"
        ws = Faye::WebSocket::Client.new(url)
        ws.onopen = lambda do |event|
          msg = {type:'websocket', command:'open', url:url}
          redis.publish :lines, msg.to_json
          puts "#{url} websocket connected."
        end
        ws.onmessage = lambda do |event|
          msg = {type:'websocket', command:'packet', url:url}
          begin
            message = JSON.parse(event.data)
            msg.message = packet
          rescue JSON::ParserError
            msg.data = event.data
          end
          redis.publish :lines, msg.to_json
          puts "#{url}: #{event.data}"
        end
        ws.onclose = lambda do |event|
          msg = {type:'websocket', command:'close', url:url}
          redis.publish :lines, msg.to_json
          puts "websocket closed for #{url}"
          EventMachine::stop_event_loop
        end
      end
      puts "Eventmachine.run for #{url} has ended. Thread closing"
      @follow_threads.delete(url)
    end
  end
end

Neuron::WebSocket.new.go
