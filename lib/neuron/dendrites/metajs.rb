#!/usr/local/ruby/1.9.2-p136/bin/ruby
require 'redis'
require 'json'
require 'neuron/dendrite'
require 'v8'
require 'httparty'
require 'net/https'

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
        if message["type"] == "emessage"
          if message["command"] == "PRIVMSG"
            raw_funcs = @redis.lrange('functions', 0, @redis.llen('functions'))
            funcs = raw_funcs.map{|f| JSON.parse(f)}
            puts funcs.inspect

            match = message["message"].match(/^js (\w+) ?(.*)?$/)
            if match
              case match.captures.first
              when "wipe"
                funcs.each_with_index do |f, idx|
                  if f["nick"] == message["nick"]
                    @redis.lrem('functions', 0, raw_funcs[idx])
                    say(message["target"], "#{message["nick"]} wiped #{f["name"]}")
                  end
                end
              when "add"
                cmd = match.captures.last.match(/(\w+) (.*)/)
                name = cmd.captures.first
                code = cmd.captures.last
                (ok, err) = js_check(cmd.captures.last, v8)
                if ok
                  add_js(message["nick"], name, code)
                  msg = "added method #{name}"
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
              end
            end
            funcs.each {|f| exec_js(v8, f["code"], message)}
          end
        end
      end
    end
  end

  def exec_js(v8, js, message)
    begin
      func = "(#{js})(#{message["message"].to_json})"
      puts "exec_js: #{func}"
      response = v8.eval(func)
      puts "response: #{response}"
      if response.to_s.length > 0
        @redis.publish :say, {"command" => "say",
                              "target" => message["target"],
                              "message" => response}.to_json
      end
    rescue V8::JSError => e
      puts "Error: #{e}"
      @redis.publish :say, {"command" => "say",
                            "target" => message["target"],
                            "message" => e.to_s}.to_json
    end
  end

  def js_check(code, v8)
    begin
      func = "(#{code})()"
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
