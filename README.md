IRC bot Framework
=================

The core is neuron.rb which listens to an IRC server, and a redis server. It bidirectionally passes messages between them. Different modules can be started/stopped/upgraded without taking down or restarting the core.

A module sends command/parameter pairs in json to a redis queue. A module can be written in any language that has a redis binding.

#### Install

    Clone the repo
    $ git clone git://github.com/donpdonp/neuronirc.git
    Copy settings.yml.sample to settings.yml and edit
    $ cp sesettings.yml.sample settings.yml
    $ vi settings.yml
    Run neuron.rb
    $ foreman start
    11:16:33 core.1          | started with pid 6172
    11:16:33 neuron-hello.1  | started with pid 6175
    11:16:33 neuron-bye.1    | started with pid 6180
    11:16:33 neuron-calc.1   | started with pid 6185

    
