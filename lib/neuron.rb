#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'daemons'
require 'irc-socket'
require 'redis'
require 'json'
require 'logger'
require 'bluepill'

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__),".."))
LOG_DIR = File.join(BASE_DIR, "log")
SETTINGS = JSON.load(File.open(File.join(BASE_DIR,"settings.json")))
STDOUT.sync = true

class Neuron
  def self.start
    bot = Neuron.new
    bot.go
  end

  def initialize
    @irc = IRCSocket.new(SETTINGS["server"])
    opts = {:base_dir => File.join(BASE_DIR,".bluepill"),
            :log_file => File.join(LOG_DIR,"bluepill")}
    @bluepill = Bluepill::Controller.new(opts)
    @redis = Redis.new
  end

  def go
    connect_irc
    Thread.new do
      listen_redis
    end
    Thread.new do
      ping_monitor
    end
    listen_irc
  end

  def connect_irc
    puts "Connecting to #{SETTINGS["server"]}"
    @irc.connect
    @irc.nick SETTINGS["nick"]
    @irc.user SETTINGS["nick"], 0, "*", "Neuron Bot"
    puts "Connected as #{SETTINGS["nick"]}"
    @last_ping = Time.now
  end

  def listen_redis
    @redis.subscribe(:say) do |on|
      on.subscribe do |channel, subscriptions|
        puts "redis: subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, json|
        begin
          message = JSON.parse(json)
          puts "redis receive: #{message}"

          if message["command"] == "say"
            puts "Saying #{message['message']} on #{message['target']}"
            @irc.privmsg(message['target'], message['message'])
          end
          if message["command"] == "join"
            puts "Joining #{message['message']}"
            @joining_channel = message['message']
            @irc.join(message['message'])
          end
          if message["command"] == "part"
            puts "Parting #{message['message']}"
            @irc.part(message['message'])
          end
          if message["command"] == "nick"
            puts "Changing nick #{message['message']}"
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
      msg = /^(:?(?<name>([^ ]*)) )?(?<command>[^ ]*)( (?<target>[^ ]*))? :?(?<message>(.*))$/.match(line.force_encoding("ISO8859-1"))
      puts "MISPARSE #{line} into #{msg.inspect}" if msg.nil?
      msg_hash = {name:msg[:name], command:msg[:command], target:msg[:target], message:msg[:message]}
      puts line

      if msg[:command] == '376'
        puts "Ready"
        predis.set('nick', SETTINGS["nick"])
        predis.publish :lines, msg_hash.to_json
      end

      if msg[:command] == '353'
        regex = msg[:message].match(/[@=] (#.*) :(.*)/)
        channel = regex[1]
        nicks = regex[2].split
        #predis.smembers(channel).each {|m| predis.srem(channel, m)} #clean out
        nicks.each {|nick| predis.sadd(channel, nick.sub('@',''))} #fill up
        known_nicks = predis.smembers(channel)
        puts "known nicks are #{known_nicks}"
      end

      if msg[:command] == '366'
        puts "end channel nick list for #{msg[:target]}: #{msg[:message]}"
        @joining_channel = nil
      end

      if msg[:command] == '433'
        puts "Nick already in use"
        predis.publish :lines, msg_hash.to_json
      end

      if msg[:command] == 'PING'
        @last_ping = Time.now
        @irc.pong(msg[:message])
      end

      if msg[:command] == 'NICK'
        nick = msg[:name].match(/(.*)!/)[1]
        if nick == predis.get('nick')
          puts "New nick #{msg[:message]}"
          predis.set('nick', msg[:message])
          predis.publish :lines, msg_hash.to_json
        end
      end

      if msg[:command] == 'PRIVMSG'
        puts "Storing #{msg_hash}"
        predis.publish :lines, msg_hash.to_json
      end

      if msg[:command] == 'JOIN'
        nick = msg[:name].match(/(.*)!/)[1]
        puts "Joined #{msg[:message]} #{nick}"
        predis.sadd(msg[:message], nick.sub('@',''))
        predis.publish :lines, msg_hash.to_json
      end

      if msg[:command] == 'PART'
        nick = msg[:name].match(/(.*)!/)[1]
        puts "Parted #{msg[:message]} #{nick}"
        # predis.srem(msg[:message], nick.sub('@',''))
        predis.publish :lines, msg_hash.to_json
      end

      if msg[:command] == 'QUIT'
        nick = msg[:name].match(/(.*)!/)[1]
        puts "Quit #{nick}"
        # todo: remove from all channels
        predis.publish :lines, msg_hash.to_json
      end
    end
  end

  def ping_monitor
    while true
      sleep 30
      if Time.now - @last_ping > 300
        puts "Ping timeout!"
      end
    end
  end
end
