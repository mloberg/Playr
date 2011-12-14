$: << '.'

require 'sinatra'
require 'sinatra/redirect_with_flash'
require 'sinatra/redis'
require 'sinatra/cache_assets'
require 'rack-flash'
require 'active_support'
require 'fileutils'
require 'json'
require 'mp3info'
require 'digest'
require 'time'
require 'packr'
require 'rainpress'

require 'lib/database'
require 'lib/app'
require 'lib/auth'
require 'lib/aacinfo'
require 'lib/lastfm'
require 'lib/web_socket'
require 'lastfm_api_key'

$lastfm = LastFM.new(LASTFM_API_KEY, LASTFM_SECRET)
$lastfm.session = LASTFM_SESSION
update_key = ActiveSupport::SecureRandom.hex(10)

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
			loop do
				tmpid = repository(:default).adapter.select("SELECT `id` FROM `songs` WHERE vote > 300 ORDER BY RAND() LIMIT 1").pop
				song = Song.get(tmpid)
				# need to make sure it hasn't been played in the past 8 hours
				played = History.last(:song => song, :played_at.gt => Time.now - 36000)
				return song unless played
			end
		end
		
	end
	
	def self.play(next_song)
		Thread.new { system "afplay -q 1 '#{next_song}'" }
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


ws = fork do
	Signal.trap("INT") do
		puts "Exiting WebSockets process ..."
		Process.exit
	end
	
	server = WebSocketServer.new(:port => 10081, :accepted_domains => ["*"])
	connections = []
	
	server.run do |ws|
		if ws.path == "/"
			begin
				ws.handshake
				que = Queue.new
				connections.push(que)
				thread = Thread.new do
					while true
						ws.send que.pop
					end
				end
				while true
					sleep 1
				end
			ensure
				connections.delete(que)
				thread.terminate if thread
			end
		elsif ws.path == "/update?key=#{update_key}"
			ws.handshake
			while data = ws.receive
				for conn in connections
					conn.push data
				end
			end
		else
			ws.handshake("404 Not Found")
		end
	end
end
Process.detach(ws)

play = fork do
	while true
		Signal.trap("INT") do
			puts "\nExiting Playr ..."
			Playr.stop
			Process.exit
		end
		
		if Playr.paused? or Playr.playing?
			sleep(1)
		else
			next_song = Playr.next_song
			next_song.adjust!(:plays => 1)
			History.create(:song => next_song, :played_at => Time.now)
			Playr.play(next_song.path)
			# websocket
			update = WebSocket.new("ws://localhost:10081/update?key=#{update_key}")
			update.send "Now playing <strong>#{next_song.title}</strong> by <strong>#{next_song.artist}</strong>"
			update.close
			# Uncomment this when in production
# 			$lastfm.update({
# 				:album => next_song.album,
# 				:track => next_song.title,
# 				:artist => next_song.artist
# 			})
		end
	end
end
Process.detach(play)