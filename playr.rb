$: << '.'

require 'sinatra/base'
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
require 'socket'

require 'lib/database'
require 'lib/app'
require 'lib/auth'
require 'lib/aacinfo'
require 'lib/lastfm'
require 'lib/web_socket'
require 'lib/server'

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
$local_ip = UDPSocket.open {|s| s.connect("64.233.187.99", 1); s.addr.last}

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
				sql = "SELECT `id` FROM `songs` WHERE vote > 300"
				# no holiday music unless it's between Thanksgiving and Christmas
				time = Time.new
				week = ((time.day - (time.wday + 1)) / 7) + 1
				unless (time.month == 11 and ((week == 4 and time.wday >= 4) or week > 4)) or (time.month == 12 and time.day < 26)
					sql << " AND (`genre` NOT LIKE 'holiday' OR `genre` NOT LIKE 'christmas' OR `genre` NOT LIKE 'season%')"
				end
				sql << " ORDER BY RAND() LIMIT 1"
				tmpid = repository(:default).adapter.select(sql).pop
				song = Song.get(tmpid)
				# need to make sure it hasn't been played in the past 8 hours
				played = History.last(:song => song, :played_at.gt => Time.now - 36000)
				return song unless played
				sleep(1)
				nil
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

ws = fork { Server.websocket(update_key) }
Process.detach(ws)

play = fork { Server.music(update_key) }
Process.detach(play)

App.run!
