#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'daemons'
require 'irc-socket'
require 'redis'
require 'json'
require 'logger'

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__),".."))
SETTINGS = JSON.load(File.open(File.join(BASE_DIR,"settings.json")))

class Neuron
  def self.start
    bot = Neuron.new
    bot.go
  end

  def initialize
    @irc = IRCSocket.new(SETTINGS["server"])
  end

  def go
    connect_irc
    Thread.new do
      listen_redis
    end
    listen_irc
  end

  def connect_irc
    puts "Connecting to #{SETTINGS["server"]}"
    @irc.connect
    @irc.nick SETTINGS["nick"] 
    @irc.user SETTINGS["nick"], 0, "*", "Neuron Bot"
    puts "Connected as #{SETTINGS["nick"]}"
  end

  def listen_redis
    redis = Redis.new
    redis.subscribe(:say) do |on|
      on.subscribe do |channel, subscriptions|
        puts "redis: subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, json|
        begin
          message = JSON.parse(json)
          puts "redis receive: #{message}"

          if message["command"] == "say"
            puts "Saying #{message['message']}"
            @irc.privmsg(message['target'], message['message'])
          end
          if message["command"] == "join"
            puts "Joining #{message['message']}"
            @irc.join(message['message'])
          end
          if message["command"] == "part"
            puts "Parting #{message['message']}"
            @irc.part(message['message'])
          end
          if message["command"] == "nick"
            puts "New nick #{message['message']}"
            @irc.nick(message['message'])
          end
        rescue  JSON::ParserError
          puts "Parse error on #{json}"
        end
      end
    end
  end
    
  def listen_irc
    predis = Redis.new
    while line = @irc.read
      msg = /^(:?(?<name>([^ ]*)) )?(?<command>[^ ]*)( (?<target>[^ ]*))? :?(?<message>(.*))$/.match(line.force_encoding("UTF-8"))
      puts "MISPARSE #{line} into #{msg.inspect}" if msg.nil?
      msg_hash = {name:msg[:name], command:msg[:command], target:msg[:target], message:msg[:message]}

      if msg[:command] == '376'
        puts "Ready"
        predis.publish :lines, msg_hash.to_json
      end

      if msg[:command] == '433'
        puts "nick already in use"
        predis.publish :lines, msg_hash.to_json
      end

      if msg[:command] == 'PING'
        @irc.pong(msg[:message])
      end

      if msg[:command] == 'PRIVMSG'
        puts "Storing #{msg_hash}"
        predis.publish :lines, msg_hash.to_json
      end
    end
  end
end
