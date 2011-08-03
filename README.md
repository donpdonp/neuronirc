IRC bot Framework
=================

The core is neuron.rb which passes messages between an IRC server and a redis server. 

The bot is extended by writing apps that use redis to listen/send messages to the bot and the current irc channel. Any language that has a redis binding will work (no irc support needed). The directory lib/neuron/dentrites/ has example modules.

#### Install

    # Clone the repo
    $ git clone git://github.com/donpdonp/neuronirc.git
    # Configure settings.json
    $ cp settings.json.sample settings.json
    $ vi settings.json
    {  "server" : "irc.freenode.net",
       "nick"   : "neuronbot"
    }

    # Start the daemon and the dendrites(bot modules)
    $ ./neuron start
    Sent start to:
      :neurond
      dendrites:bye
      dendrites:calc
      dendrites:hello

    # Status
    $ ./neuron 
    neuron is running as nick: neuronbot
    neurond(pid:29575): up
    
    dendrites:
      bye(pid:29585): up
      calc(pid:29595): up
      hello(pid:29605): up

    # Tell the bot to join a channel
    $ ./neuron join '#somechannel'
    {"command"=>"join", "message"=>"#somechannel"}

    # Restart the dendrites (after updating lib/neuron/dentrites/*)
    $ ./neuron restart
    Sent restart to:
      dendrites:bye
      dendrites:calc
      dendrites:hello

    # Stop the dendrites and quit the daemon
    $ ./neuron quit
    Sent stop to:
      :neurond
      dendrites:bye
      dendrites:calc
      dendrites:hello
    Killing bluepilld[29382]

