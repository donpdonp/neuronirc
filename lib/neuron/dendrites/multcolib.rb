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
    if message.has_key?("type") && message["type"] == "emessage"
      target = message["target"][0] == "#"  ? message["target"] : message["nick"]

      solve = message["message"].match(/^\s*!?library\s+auth\s+(.*)/)
      if solve && solve.captures.size > 0

        cmds = solve.captures.first.split

        agent.get('http://multcolib.org')
        msg = agent.page.title
        agent.page.link_with(:text =>"My account").click
        signin = agent.page.form('patform')
        signin.code = cmds[0]
        signin.pin = cmds[1]
        agent.submit(signin, signin.buttons.first)
        notices = agent.page.search('span.loggedInMessage')
        if notices.size > 0
          msg = notices.first.text
          predis.set("multcolib-#{message["nick"]}", "#{cmds[0]}-#{cmds[1]}")
          msg = "Authentication successful. Credentials saved for #{message["nick"]}"
        else
          msg = agent.page.search('//font/em').text.strip
        end

        predis.publish :say, {"command" => "say",
                    "target" => target,
                    "message" => msg}.to_json
        agent.page.link_with(:text =>"Log out").click
      end

      solve = message["message"].match(/^\s*!?library\s+books?/)
      if solve
        creds = predis.get("multcolib-#{message["nick"]}")
        if creds
          agent.get('https://catalog.multcolib.org/patroninfo~S1')

          signin = agent.page.form('patform')
          signin.code = creds.split('-').first
          signin.pin = creds.split('-').last
          agent.submit(signin, signin.buttons.first)
          notices = agent.page.search('span.loggedInMessage')
          if notices.size > 0
            agent.page.link_with(:text=>/currently checked out/).click
            agent.page.search('tr.patFuncEntry').map do |book|
              title = book.search('td.patFuncTitle').text.strip
              due = book.search('td.patFuncStatus').text.strip
              msg = "#{title} #{due}"
              predis.publish :say, {"command" => "say",
                "target" => target,
                "message" => msg}.to_json
            end
            agent.page.link_with(:text =>"Log out").click
          else
            msg = agent.page.search('//font/em').text.strip
            predis.publish :say, {"command" => "say",
              "target" => target,
              "message" => msg}.to_json
          end
        else
          msg ="no creds! /msg #{predis.get('nick')} library auth <card no> <pin>"
          predis.publish :say, {"command" => "say",
            "target" => target,
            "message" => msg}.to_json
        end
      end
    end
  end
end