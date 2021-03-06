require 'json'
require 'httparty'
require 'haversine'
require 'redis'
require 'yaml'
require 'foursquare2'
require 'faraday'
require 'multi_json'


STDOUT.sync = true
BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__),"."))
SETTINGS = JSON.load(File.open(File.join(BASE_DIR,"../../../settings.json")))

@redis = Redis.new
@predis = Redis.new
fsq = Foursquare2::Client.new(:oauth_token => SETTINGS["oauth"]["access_token"])

@redis.subscribe(:lines) do |on|
  on.subscribe do |channel, subscriptions|
    puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
  end

  on.message do |channel, json|
    message = JSON.parse(json)
    if message["type"] == "emessage" && message["target"][0] == '#' && message["to_me"] == "true"
      expr = message["message"].match(/what'?s next\??/)
      if expr

        checkins = fsq.recent_checkins

        #get couchdb document
        user = {"name" => message["nick"].sub(/_$/,'')}

        # Future where/when
        puts "checking #{user["name"]} plancast"
        plans = HTTParty.get "http://api.plancast.com/02/plans/user.json?username=#{user["name"]}&extensions=place", :format => :json

        if plans["plans"]
          if plans["plans"].length > 0
            plan = plans["plans"].first
            plan["start"] = plan["start"].to_i+(8*60*60) # plancast uses localtime oh noes
            puts plan.inspect
            msg = "#{message["nick"]}: \"#{plan["what"]}\" at \"#{plan["where"]}\" happens at  #{Time.at(plan["start"].to_i).strftime("%b %e %I:%M%P")}. "
          else
            msg = "#{message["nick"]}: no plans in your plancast account. "
          end
        else
          msg = "#{message["nick"]}: no plancast account found. "
        end

        # Present where/when
        # icecondor
        #now  = HTTParty.get 'http://icecondor.com/locations.json?id=http://donpark.org/', :format => :json
        #loc = now.first["location"]
        #puts "donpdonp was last seen at #{loc["geom"]["y"]},#{loc["geom"]["x"]} #{loc["timestamp"]} "
        # geoloqi
        # foursquare
        puts "checking #{user["name"]} foursquare"
        fusers = fsq.search_users(:twitter => user["name"].downcase)
        if fusers.results.length > 0
          if fusers.results.length  == 1
            fuser = fusers.results.first
            seen = checkins.select{|c| c.user.id == fuser.id}
            loc = seen.first
            if loc
              puts loc.inspect
              msg += "I last saw you at \"#{loc.venue.name}\" #{Time.at(loc.createdAt).strftime("%b %e %I:%M%P")}. "
            else
              msg += "No recent 4sq checkin."
            end
          else
            msg += "username is ambiguous on 4sq. "
          end
        else
          msg += "No 4sq account found. "
        end

        if plan && loc
          # distance
          puts "#{plan["place"]["latitude"].to_f} #{plan["place"]["longitude"].to_f} - #{loc.venue.location.lat} #{loc.venue.location.lng}"
          distance = Haversine.distance(plan["place"]["latitude"].to_f, plan["place"]["longitude"].to_f,
                                        loc.venue.location.lat, loc.venue.location.lng)
          distance = distance.to_miles.to_f
          puts "#{Time.at(plan["start"])} #{Time.at(loc.createdAt)}"
          #time_distance = plan["start"].to_i - loc.createdAt
          time_distance = plan["start"].to_i - Time.now.to_i
          time_distance_in_hours = time_distance/60/60.0
          msg += "if you left now, #{"%0.1f" % (distance/time_distance_in_hours)} mph needed to cover"
          msg += " #{"%0.1f" % distance}mi in" +
                " #{"%0.1f" % (time_distance_in_hours)} hours. "
        end
        @predis.publish :say, {"command" => "say",
                              "target" => message["target"],
                              "message" => msg}.to_json
      end
    end
  end
end
