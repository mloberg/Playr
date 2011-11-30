$: << '.'

require 'sinatra'
require 'rack-flash'
require 'sinatra/redirect_with_flash'
require 'active_support/secure_random'
require 'sinatra/redis'
require 'fileutils'
require 'json'
require 'mp3info'
require 'digest'
require 'time'

require 'lib/database'
require 'lib/app'
require 'lib/functions'

class Playr

	class << self
		attr_accessor :play
		attr_accessor :paused
	end
	
	def self.queue
		if self.play
			puts "start the queue"
		else
			puts "not playing"
		end
	end
	
	def self.stop
		self.play = false
	end

end

Playr.play = true
Playr.queue

pid = fork do
	while true
		Signal.trap("INT") do
			puts "Stop playing the current song."
			puts "Some other cleanup stuff."
			Process.exit # do a clean exit
		end
		
		# if Playr.playing?
		
		sleep(1)
	end
end
Process.detach(pid)