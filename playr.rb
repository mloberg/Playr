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
	
	def self.next_song
		# check queue
		
		# if queue is empty, pick one at random preferring those with a higher vote
		
	end
	
	def self.play(next_song)
		system "afplay -q 1 #{next_song}"
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
	
	def self.volume=(num)
		system "osascript -e 'set volume output volume #{num}' 2>/dev/null"
	end
	
	def self.volume
		vol = `osascript -e 'get output volume of (get volume settings)'`
		vol.to_i
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
		
		if Playr.paused? or Playr.playing?
			sleep(1)
		else
			# get the next song
			# next_song = Playr.next_song
			# play the song
			# Playr.play(next_song)
		end
	end
end
Process.detach(pid)