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
require 'highline/import'
require 'thread'

require 'lib/database'
require 'lib/app'
require 'lib/auth'
require 'lib/aacinfo'
require 'lib/lastfm'
require 'lib/web_socket'

unless File.exists?('lastfm_api_key.rb')
	puts "\nNo Last.fm config file found. Creating one now."
	print "Your Last.fm API Key: "
	api_key = STDIN.gets.chomp
	print "Your Last.fm Secret Key: "
	secret_key = STDIN.gets.chomp
	File.open('lastfm_api_key.rb', 'w') { |f| f.write("LASTFM_API_KEY = '#{api_key}'\nLASTFM_SECRET = '#{secret_key}'\n") }
end

require 'lastfm_api_key'
$lastfm = LastFM.new(LASTFM_API_KEY, LASTFM_SECRET)

unless defined?(LASTFM_SESSION)
	print "Do you want to generate a Last.fm session? [y/n]"
	if STDIN.gets.chomp =~ /n|N|no/
		LASTFM_SESSION = nil
		File.open('lastfm_api_key.rb', 'a') { |f| f << "LASTFM_SESSION = nil" }
	else
		puts "Generating Last.fm session..."
		print "Please hit enter to authorize Playr (this will open up your browser)."
		STDIN.gets
		token = $lastfm.auth_token
		system("open 'http://www.last.fm/api/auth/?api_key=#{LASTFM_API_KEY}&token=#{token}'")
		print "Once you have authorized the app, please hit enter..."
		STDIN.gets
		LASTFM_SESSION = $lastfm.auth_session(token)
		if LASTFM_SESSION == nil
			puts "Could not get auth session. Please try again."
			Process.exit
		end
		File.open('lastfm_api_key.rb', 'a') { |f| f << "LASTFM_SESSION = '#{LASTFM_SESSION}'" }
	end
	puts "Last.fm config file created!"
end

$lastfm.session = LASTFM_SESSION if LASTFM_SESSION

if User.all.empty?
	print "Would you like to create the admin user? [y/n]"
	if STDIN.gets.chomp =~ /y|Y|yes/
		print "Username: "
		username = STDIN.gets.chomp
		password = ask("Password: ") { |q| q.echo = "*" }
		print "Name: "
		name = STDIN.gets.chomp
		u = User.create(
			:username => username,
			:password => Auth.hash_password(password),
			:secret => ActiveSupport::SecureRandom.hex(16),
			:name => name
		)
		puts "User #{username} created."
	end
end

update_key = ActiveSupport::SecureRandom.hex(10)

puts "== Starting Playr ..."

class Playr
	
	class << self; attr_accessor :pause_file end
	@@pause_file = '/tmp/playr_is_paused'
	
	def self.next_song
		# check queue
		queued = SongQueue.first
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

ws = fork do
	def kill_process
		Process.exit
	end
	Signal.trap("INT", "kill_process")
	Signal.trap("TERM", "kill_process")
	Signal.trap("VTALRM", "kill_process")
	server = WebSocketServer.new(:port => 10081, :accepted_domains => ["*"])
	web_connections = []
	desk_connections = []
	
	server.run do |ws|
		if ws.path == "/"
			begin
				ws.handshake
				que = Queue.new
				web_connections.push(que)
				thread = Thread.new do
					while true
						ws.send que.pop
					end
				end
				while true
					sleep 1
				end
			ensure
				web_connections.delete(que)
				thread.terminate if thread
			end
		elsif ws.path == "/notify"
			begin
				ws.handshake
				que = Queue.new
				desk_connections.push(que)
				thread = Thread.new do
					while true
						ws.send que.pop
					end
				end
				while true
					sleep 1
				end
			ensure
				desk_connections.delete(que)
				thread.terminate if thread
			end
		elsif ws.path == "/update?key=#{update_key}"
			ws.handshake
			while data = ws.receive
				for conn in web_connections
					conn.push data
				end
			end
		elsif ws.path == "/notify?key=#{update_key}"
			ws.handshake
			while data = ws.receive
				for conn in desk_connections
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
	def kill_process
		puts "== Stopping Playr"
		Playr.stop
		Process.exit
	end
	while true
		Signal.trap("INT", "kill_process")
		Signal.trap("TERM", "kill_process")
		Signal.trap("VTALRM", "kill_process")
		
		if Playr.paused? or Playr.playing? or Song.all.empty?
			sleep(1)
		else
			next_song = Playr.next_song
			next_song.adjust!(:plays => 1)
			History.create(:song => next_song, :played_at => Time.now)
			Playr.play(next_song.path)
			# web users
			update = WebSocket.new("ws://127.0.0.1:10081/update?key=#{update_key}")
			update.send "Now playing <strong>#{next_song.title}</strong> by <strong>#{next_song.artist}</strong>"
			update.close
			# growl users
			growl = WebSocket.new("ws://127.0.0.1:10081/notify?key=#{update_key}")
			growl.send({ :title => "Playr Now Playing", :message => "#{next_song.title} by #{next_song.artist}" }.to_json)
			if LASTFM_SESSION
				$lastfm.update({
					:album => next_song.album,
					:track => next_song.title,
					:artist => next_song.artist
				})
			end
		end
	end
end
Process.detach(play)