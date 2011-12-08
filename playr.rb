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
require 'lib/aacinfo'

class Playr
	
	class << self; attr_accessor :pause_file end
	@@pause_file = '/tmp/playr_is_paused'
	
	def self.next_song
		# check queue
		queued = Queue.first
		if queued
			queued.destroy
			return queued.song
		else
			# if queue is empty, pick one at random preferring those with a higher vote
			tmpid = repository(:default).adapter.select("SELECT `id` FROM `songs` WHERE vote > 300 ORDER BY RAND() LIMIT 1").pop
			song = Song.get(tmpid)
			return song
		end
		
	end
	
	def self.play(next_song)
		fork { system "afplay -q 1 '#{next_song}'" }
	end
	
	def self.pause
		paused? ? `rm -f #{@@pause_file}` : `touch #{@@pause_file}`
		`killall afplay > /dev/null 2>&1`
	end
	
	def self.stop
		`rm -f #{@@pause_file}`
		`killall afplay > /dev/null 2>&1`
	end
	
	def self.skip
		was_paused = paused?
		pause
		pause unless was_paused
	end
	
	def self.playing?
		`ps aux | grep afplay | grep -v grep | wc -l | tr -d ' '`.chomp != "0"
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

Playr.pause

pid = fork do
	while true
		Signal.trap("INT") do
			puts "Stopping the currently played song."
			Playr.stop
			puts "Exiting Playr..."
			Process.exit # do a clean exit
		end
		
		if Playr.paused? or Playr.playing?
			sleep(1)
		else
			# get the next song
			next_song = Playr.next_song
			next_song.adjust!(:plays => 1)
			# add song to play table
			History.create(:song => next_song, :started_at => Time.now)
			# play the song
			Playr.play(next_song.path)
		end
	end
end
Process.detach(pid)