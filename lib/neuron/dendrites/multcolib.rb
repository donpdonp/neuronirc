require 'json'
require 'redis'
require 'mechanize'

STDOUT.sync = true
BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__),"."))
SETTINGS = JSON.load(File.open(File.join(BASE_DIR,"../../../settings.json")))

STDOUT.sync = true
redis = Redis.new
predis = Redis.new
agent = Mechanize.new

redis.subscribe(:lines) do |on|
  on.subscribe do |channel, subscriptions|
    puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
  end
  on.message do |channel, json|
    message = JSON.parse(json)
    puts "Heard #{message}"
    if message.has_key?("type") && message["type"] == "emessage"

      solve = message["message"].match(/^\s*!?library\s+(.*)/)
      if solve && solve.captures.size > 0
        target = message["target"][0] == "#"  ? message["target"] : message["nick"]

        cmds = solve.captures.first.split

        agent.get('http://multcolib.org')
        msg = agent.page.title

        predis.publish :say, {"command" => "say",
                    "target" => target,
                    "message" => msg}.to_json

        msg = "Authenticating with #{cmds[1]} #{cmds[2]}"

        predis.publish :say, {"command" => "say",
                    "target" => target,
                    "message" => msg}.to_json

        agent.page.link_with(:text =>"My account").click
        signin = agent.page.form('patform')
        signin.code = cmds[1]
        signin.pin = cmds[2]
        agent.submit(signin, signin.buttons.first)
        notices = agent.page.search('span.loggedInMessage')
        if notices.size > 0
          msg = notices.first.text
        else
          msg = agent.page.search('//font/em').text.strip
        end

        predis.publish :say, {"command" => "say",
                    "target" => target,
                    "message" => msg}.to_json
      end
    end
  end
end