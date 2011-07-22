#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'daemons'
require 'irc-socket'
require 'redis'
require 'json'
require 'logger'

DEBUG = ARGV[0] == "debug"

SETTINGS = JSON.parse(File.open("settings.json").read)

if ARGV[0] == "daemon"
  logfile = File.expand_path("log", File.dirname(__FILE__))
else
  logfile = STDOUT
end

log_opts = {:app_name => 'neuron.rb', 
            :log_output => true}
Daemons.daemonize(log_opts) if ARGV[0] == "daemon"
LOG = Logger.new(logfile)

predis = Redis.new
irc = IRCSocket.new(SETTINGS["server"])
LOG.info "Connecting to #{SETTINGS["server"]}"
irc.connect
irc.nick SETTINGS["nick"] 
irc.user SETTINGS["nick"], 0, "*", "Neuron Bot"
LOG.info "Connected as #{SETTINGS["nick"]}"

Thread.new do
  redis = Redis.new
  redis.subscribe(:say) do |on|
    on.subscribe do |channel, subscriptions|
      LOG.info "redis: subscribed to ##{channel} (#{subscriptions} subscriptions)"
    end
    on.message do |channel, json|
      begin
        message = JSON.parse(json)
        LOG.info "redis receive: #{message}"

        if message["command"] == "say"
          LOG.info "Saying #{message['message']}"
          irc.privmsg(message['target'], message['message'])
        end
        if message["command"] == "join"
          LOG.info "Joining #{message['message']}"
          irc.join(message['message'])
        end
        if message["command"] == "part"
          LOG.info "Parting #{message['message']}"
          irc.part(message['message'])
        end
        if message["command"] == "nick"
          LOG.info "New nick #{message['message']}"
          irc.nick(message['message'])
        end
      rescue  JSON::ParserError
        LOG.info "Parse error on #{json}"
      end
    end
  end
end

while line = irc.read
  LOG.debug line if DEBUG
  msg = /^(:?(?<name>([^ ]*)) )?(?<command>[^ ]*)( (?<target>[^ ]*))? :?(?<message>(.*))$/.match(line.force_encoding("UTF-8"))
  LOG.error "MISPARSE #{line} into #{msg.inspect}" if msg.nil?
  msg_hash = {name:msg[:name], command:msg[:command], target:msg[:target], message:msg[:message]}

  if msg[:command] == '376'
    LOG.info "Ready"
    predis.publish :lines, msg_hash.to_json
  end

  if msg[:command] == '433'
    LOG.info "nick already in use"
    predis.publish :lines, msg_hash.to_json
  end

  if msg[:command] == 'PING'
    irc.pong(msg[:message])
  end

  if msg[:command] == 'PRIVMSG'
    LOG.info "Storing #{msg_hash}"
    predis.publish :lines, msg_hash.to_json
  end
end

LOG.info "finished."
