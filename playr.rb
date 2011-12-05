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
	
	class << self; attr_accessor :pause_file end
	@@pause_file = '/tmp/playr_is_paused'
	
	def self.start
		if self.play
			puts "start the queue"
		else
			puts "not playing"
		end
	end
	
	def self.play
		
	end
	
	def self.pause
		paused? ? `rm -f #{@@pause_file}` : `touch #{@@pause_file}`
		`killall afplay > /dev/null 2>&1`
	end
	
	def self.stop
		self.play = false
	end
	
	def self.playing?
		`ps aux | grep afplay | grep -v grep | wc -l | tr -d ' '`.chomp != 0
	end
	
	def self.paused?
		File.exist?(@@pause_file)
	end

end

pid = fork do
	while true
		Signal.trap("INT") do
			`rm -f #{Playr.pause_file}` # remove tmp pause file
			puts "Stop playing the current song."
			puts "Some other cleanup stuff."
			Process.exit # do a clean exit
		end
		
		if Playr.paused?
			sleep(1)
		else
			sleep(1)
		end
	end
end
Process.detach(pid)