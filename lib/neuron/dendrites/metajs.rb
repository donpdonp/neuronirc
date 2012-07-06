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

    redis = Redis.new
    credis = Redis.new
    credis.del('functions') # clean out possible DOS functions
    redis.subscribe(:lines) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, json|
        message = JSON.parse(json)
        puts "Heard #{message}"
        if message["type"] == "emessage"
          if message["target"][0] == '#'
            funcs = credis.lrange('functions', 0, credis.llen('functions'))

            funcs.each do |func|
              begin
                puts "parsing: #{func}"
                func = "(#{func})(#{message["message"].to_json})"
                puts "parsing2: #{func}"
                response = v8.eval(func)
                puts "got: #{response}"
                if response.to_s.length > 0
                  @redis.publish :say, {"command" => "say",
                                        "target" => message["target"],
                                        "message" => response}.to_json
                end
              rescue V8::JSError => e
                puts "Error: #{e}"
              end
            end

            if match = message["message"].match(/^responder wipe$/)
              credis.del('functions')
              msg = "all functions wiped"
              @redis.publish :say, {"command" => "say",
                                    "target" => message["target"],
                                    "message" => msg}.to_json
              return
            end

            if match = message["message"].match(/^responder (.*)/)
              begin
                func = "(#{match.captures.first})()"
                puts "add parsing: #{func}"
                response = v8.eval(func)
                msg = "adding #{match.captures.first}"
                credis.rpush('functions', match.captures.first)
                # run it through the defined functions
                # say the result
                @redis.publish :say, {"command" => "say",
                                      "target" => message["target"],
                                      "message" => msg}.to_json
              rescue NoMethodError => e
                @redis.publish :say, {"command" => "say",
                                      "target" => message["target"],
                                      "message" => e.to_s}.to_json
              rescue V8::JSError => e
                @redis.publish :say, {"command" => "say",
                                      "target" => message["target"],
                                      "message" => e.to_s}.to_json
              end
            end

            if match = message["message"].match(/^responder$/)
              msg = "funcs #{funcs.inspect}"
              # run it through the defined functions
              # say the result
              @redis.publish :say, {"command" => "say",
                                    "target" => message["target"],
                                    "message" => msg}.to_json
            end

          end
        end
      end
    end
  end
end

class MyHttp
  def get(url)
    begin
      uri = URI(url)
      if uri.scheme == "https"
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Get.new(uri.request_uri)

        response = http.request(request)
        resp = response.body
      else
        resp = Net::HTTP.get(URI(url))
      end
      JSON.parse(resp)
    rescue JSON::ParserError => e
      {:error => e.to_s}
    end
  end
end

Metajs.new.go
