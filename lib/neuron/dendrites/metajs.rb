#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'neuron/dendrite'
require 'v8'
require 'httparty'
require 'net/https'

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__),"../../.."))
SETTINGS = JSON.load(File.open(File.join(BASE_DIR,"settings.json")))

STDOUT.sync = true

class Metajs
  include Neuron::Dendrite

  def go
    setup
    v8 = V8::Context.new
    v8['http'] = MyHttp.new

    Redis.new.subscribe(:lines) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel}"
      end

      on.message do |channel, json|
        message = JSON.parse(json)
        puts "Heard #{message}"

        raw_funcs = @redis.lrange('functions', 0, @redis.llen('functions'))
        funcs = raw_funcs.map{|f| JSON.parse(f)}

        ignore = false
        if message["command"] == "PRIVMSG"
          if message["type"] == "emessage"

            match = message["message"].match(/^js (\w+) ?(.*)?$/)
            if match
              ignore = dispatch(v8, raw_funcs, funcs, match, message)
            end
          else
            ignore = true
          end
        end
        funcs.each do |f|
          func = "(#{f["code"]})(JSON.parse(#{message.to_json.to_json}))"
          puts "#{f["nick"]}/#{f["name"]}"
          say = exec_js(v8, func, f["nick"], message)
        end unless ignore
      end
    end
  end

  def dispatch(v8, raw_funcs, funcs, match, message)
    ignore = true
    case match.captures.first
    when "wipe"
      funcs.each_with_index do |f, idx|
        if f["nick"] == message["nick"]
          @redis.lrem('functions', 0, raw_funcs[idx])
          say(message["target"], "#{message["nick"]}: wiped method #{f["name"]}")
        end
      end
    when "del"
      cmd = match.captures.last.match(/(\w+)/)
      if cmd
        fname = cmd.captures.first
        js_del_by_name(raw_funcs, funcs, fname, message)
      end
    when "add"
      cmd = match.captures.last.match(/(\w+)\s+(.*)/)
      name = cmd.captures.first
      code = cmd.captures.last
      if code.match(/^http/)
        url = code
        uri = URI.parse(url)
        if uri.host == "gist.github.com"
          load_url = gist_raw_url(uri)
        else
          load_url = url
        end
        say(message["target"], "Loading #{load_url}")
        request = HTTParty.get(load_url)
        if request.response.is_a?(Net::HTTPOK)
          code = request.body
        else
          say(message["target"], "#{url} #{request.response}")
          return
        end
      end
      (ok, err) = js_check(code, v8)
      if ok
        js_del_by_name(raw_funcs, funcs, name, message)
        add_js(message["nick"], name, code, url)
        msg = "#{message["nick"]}: added method #{name} (#{code.length} bytes)"
        say(message["target"],msg)
      else
        say(message["target"], err.to_s)
      end
    when "list"
      # run it through the defined functions
      list = funcs.select{|f| f}.map{|f| "#{f["nick"]}/#{f["name"]}"}
      msg = "funcs: #{list.inspect}"
      # say the result
      say(message["target"], msg)
    when "show"
      cmd = match.captures.last.match(/(\w+)/)
      if cmd
        fname = cmd.captures.first
        sname = cmd.captures.first
        list = funcs.select{|f| f["name"] == sname && f["nick"] == message["nick"]}
        if list.length > 0
          say(message["target"], list.first["code"].gsub("\n",''))
        else
          say(message["target"], "Script #{message["nick"]}/#{sname} not found")
        end
      end
    when "eval"
      js = match.captures.last
      puts "eval: #{js}"
      jjs = "JSON.stringify((#{js}))"
      value = exec_js(v8, jjs, message["nick"], message)
    when "help"
      say(message["target"], "list, add <name> <code or url>, show <name>, del <name>, eval <code>")
    else
      ignore = false
    end
    return [ignore, value]
  end

  def exec_js(v8, js, nick, message)
    begin
      v8['db'] = RedisStore.new(nick)
      response = v8.eval(js)
      puts "response: #{response.class} #{response}" if response
      if response.is_a?(String)
        if response.to_s.length > 0
          say = {"command" => "say",
                 "target" => message["target"],
                 "message" => response}.to_json
        end
      end
      if response.is_a?(V8::Object)
        say = {"command" => "say",
               "target" => response["target"],
               "message" => response["message"]}.to_json
      end
    rescue V8::JSError => e
      puts "Error: #{e}"
      say = {"command" => "say",
             "target" => message["target"],
             "message" => e.to_s}.to_json
    end

    @redis.publish :say, say if say
  end

  def js_check(code, v8)
    begin
      func = "(#{code})"
      puts "checking: #{func}"
      response = v8.eval(func) #syntax check
      return true
    rescue NoMethodError => e
      return [false, e]
    rescue V8::JSError => e
      return [false, e]
    end
  end

  def add_js(nick, name, code, url)
      jmethod = {nick: nick, name: name, code: code, url: url}
      puts jmethod.inspect
      @redis.rpush('functions', jmethod.to_json)
  end

  def js_del_by_name(raw_funcs, funcs, name, message)
    funcs.each_with_index do |f, idx|
      if f["name"] == name && f["nick"] == message["nick"]
        @redis.lrem('functions', 0, raw_funcs[idx])
        say(message["target"], "#{message["nick"]}: wiped method #{name}")
      end
    end
  end

  def gist_raw_url(uri)
    request = HTTParty.get("https://api.github.com/gists"+uri.path)
    gist = JSON.parse(request.body)
    gist["files"]["gistfile1.txt"]["raw_url"]
  end
end

class MyHttp
  def get(url)
    uri = URI(url)
    if uri.scheme == "https"
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Get.new(uri.request_uri)

        response = http.request(request)
        response.body
      end
    else
      Net::HTTP.get(uri)
    end
  end
end

class RedisStore
  def initialize(nick)
    @nick = nick
    @redis = Redis.new
  end

  def setkey
    "#{@nick}:keys"
  end

  def valuekey(key)
    "#{@nick}:keyspace:#{key}"
  end

  def set(key, value)
    @redis.sadd(setkey, key)
    @redis.set(valuekey(key), value)
  end

  def get(key)
    if @redis.sismember(setkey, key)
      @redis.get(valuekey(key))
    end
  end

  def del(key)
    if @redis.sismember(setkey, key)
      @redis.srem(setkey, key)
      @redis.del(valuekey(key))
    end
  end
end

Metajs.new.go
