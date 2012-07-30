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
                cmd = match.captures.last.match(/(\w+) (.*)/)
                name = cmd.captures.first
                js_del_by_name(raw_funcs, funcs, name, message)
                code = cmd.captures.last
                if code.match(/^http/)
                  request = HTTParty.get(code)
                  if request.response.is_a?(Net::HTTPOK)
                    code = request.body
                  else
                    say(message["target"], request.response.to_s)
                    return
                  end
                end
                (ok, err) = js_check(code, v8)
                if ok
                  add_js(message["nick"], name, code)
                  msg = "added method #{name} (#{code.length} bytes)"
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
                  list = funcs.select{|f| f["name"] == cmd.captures.first && f["nick"] == message["nick"]}
                  say(message["target"], list.first["code"].gsub("\n",''))
                end
              end
            end
          else
            ignore = true
          end
        end
        funcs.each {|f| exec_js(v8, f["code"], message)} unless ignore
      end
    end
  end

  def exec_js(v8, js, message)
    begin
      func = "(#{js})(JSON.parse(#{message.to_json.to_json}))"
      puts "exec_js: #{func}"
      response = v8.eval(func)
      puts "response: #{response.class} #{response}"
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
      func = "(#{code})({})"
      puts "checking: #{func}"
      response = v8.eval(func) #syntax check
      return true
    rescue NoMethodError => e
      return [false, e]
    rescue V8::JSError => e
      return [false, e]
    end
  end

  def add_js(nick, name, code)
      jmethod = {nick: nick, name: name, code: code}
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
end

class MyHttp
  def get(url)
    uri = URI(url)
    if uri.scheme == "https"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri.request_uri)

      response = http.request(request)
      response.body
    else
      Net::HTTP.get(URI(url))
    end
  end
end

Metajs.new.go
