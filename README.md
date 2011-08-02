IRC bot Framework
=================

The core is neuron.rb which listens to an IRC server, and a redis server. It bidirectionally passes messages between them. Different modules can be started/stopped/upgraded without taking down or restarting the core.

A module sends command/parameter pairs in json to a redis queue. A module can be written in any language that has a redis binding.

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
