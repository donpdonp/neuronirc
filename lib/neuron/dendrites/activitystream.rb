require 'neuron/dendrite'
require 'rethinkdb'

STDOUT.sync = true

class ActivityStream
  include Neuron::Dendrite
  include RethinkDB::Shortcuts

  def rethink_setup
    db_name = 'activitystream'
    @table_name = 'activity'
    @conn = r.connect()
    unless r.db_list.run(@conn).include?(db_name)
      puts "Warning: creating db #{db_name}"
      r.db_create(db_name).run(@conn)
    end
    @conn.use(db_name)

    unless r.db(db_name).table_list().run(@conn).include?(@table_name)
      puts "Warning: creating table #{@table_name}"
      r.table_create(@table_name).run(@conn)
    end
    puts "rethinkdb db activitystream connected."
  end

  def go
    setup
    rethink_setup
    on_message do |channel, message|
      if message["command"] == "checkin"
        dispatch(message)
      end
    end
  end

  def dispatch(message)
    doc = build_activitystream(message)
    puts "Inserting #{doc.inspect}"
    r.table(@table_name).insert(doc).run(@conn)
  end

  def build_activitystream(message)
    act = {
      verb: message["command"],
      provider: message["type"],
      published: Time.now.iso8601
    }
    if message["checkin"]
      act["subject"] = { objectType: "person", 
                   twitter: message["checkin"]["user"]["contact"]["twitter"]}
      act["object"] = { objectType: "place",
                        name: message["checkin"]["venue"]["name"]}
    else
      act["payload"] = message
    end
    act
  end

end

ActivityStream.new.go
