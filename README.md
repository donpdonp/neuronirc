IRC bot Framework
=================

The core is neuron.rb which passes messages between an IRC server and a redis server. 

The bot is extended by writing apps that use redis to listen/send messages to the bot and the current irc channel. Any language that has a redis binding will work (no irc support needed). The directory lib/neuron/dentrites/ has example modules.

#### Install

    #Clone the repo
    $ git clone git://github.com/donpdonp/neuronirc.git
    #Copy settings.json.sample to settings.json and edit
    $ cp settings.json.sample settings.json
    $ vi settings.json
    {  "server" : "irc.freenode.net",
       "nick"   : "neuronbot"
    }
    #Start the daemon
    $ ./neuron start
    Sent start to:
      :neuron.rb
       :dendrites/bye.rb
       :dendrites/calc.rb
       :dendrites/hello.rb
    $ ./neuron join '#somechannel'
    {"command"=>"join", "message"=>"#somechannel"}

