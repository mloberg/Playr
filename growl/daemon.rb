#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

Daemons.run('/usr/local/var/playr/growl.rb')