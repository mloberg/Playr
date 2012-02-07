APP_DIR = File.expand_path(File.dirname(__FILE__))
$: << APP_DIR
require "rake"

def load_config
	require "yaml"
	@config = YAML.load_file("#{APP_DIR}/config/config.yml")
end

def load_redis
	require "redis"
	load_config unless @config
	@redis = Redis.new(:host => @config['redis']['host'], :port => @config['redis']['port'])
end

def start_pause
	`touch #{APP_DIR}/tmp/pause`
	kill_afplay
end

def stop_pause
	`rm -f #{APP_DIR}/tmp/pause`
end

def kill_afplay
	`killall afplay > /dev/null 2>&1`
end

task :default => 'playr:commands'

namespace :playr do
	require "lib/worker"

	task :commands do
		puts "Playr Commands: "
		puts "    rake playr:start          # starts web and music servers."
		puts "    rake playr:stop           # stops web and music servers."
		puts "    rake playr:restart        # restart web and music servers."
		puts "    rake playr:play           # unpause music server."
		puts "    rake playr:pause          # pauses music server."
		puts "    rake playr:skip           # skip current song."
		puts "    rake playr:volume[level]  # set the system volume."
	end

	desc "Start Playr and its sub-processes"
	task :start do
		# make sure god is running
		if `ps aux | grep god | grep -v grep | wc -l | tr -d ' '`.chomp == "0"
			`god -c #{APP_DIR}/playr.god`
		end
		`god start playr`
	end

	desc "Stop Playr and its sub-processes"
	task :stop do
		start_pause
		`god stop playr`
		stop_pause
		`god terminate`
	end

	desc "Restart Playr and its sub-processes"
	task :restart do
		`god restart playr`
	end

	desc "Start the music"
	task :play do
		if Playr::Worker.paused?
			stop_pause
		end
	end

	desc "Pause/play the music"
	task :pause do
		if Playr::Worker.paused?
			stop_pause
		else
			start_pause
		end
	end

	desc "Skip the current song"
	task :skip do
		unless Playr::Worker.paused?
			kill_afplay
		end
	end

	task :next do
		Rake::Task["playr:skip"].invoke
	end

	desc "Set volume level"
	task :volume, :level do |t, args|
		volume = args[:level]
		if volume.to_i != 0
			system("osascript -e 'set volume output volume #{volume}' 2>/dev/null")
		end
	end

end

namespace :setup do

	desc "Get Last.fm Session key"
	task :lastfm_session do
		load_config
		if @config["lastfm"]["api_key"] == nil
			puts "Please enter your Last.fm API and secret key into config/config.yml"
		else
			require "lib/lastfm"
			load_redis
			lfm = Playr::Lastfm.new(@config['lastfm'], @redis)
			token = lfm.auth_token
			system("open 'http://www.last.fm/api/auth/?api_key=#{@config["lastfm"]["api_key"]}&token=#{token}'")
			puts "Once you have authorized the app, hit enter..."
			STDIN.gets
			puts "Your Last.fm session key is: #{lfm.auth_session(token)}"
			puts "Please add this to config.yml"
		end
	end

	desc "Add User"
	task :user, :username, :pass do |t, args|
		require "lib/database"
		if User.add({ :username => args[:username], :password => args[:password] })
			puts "Added #{args[:username]}."
		else
			puts "Could not add user."
		end
	end

end

namespace :music do

	desc "Normalize all audio files"
	task :normalize do
		# normalize all audio files by adding them as a task to redis
		load_redis
		files = Dir.glob("music/*/*/*")
		files.each do |f|
			redis.rpush "tasks", "normalize:./#{f}"
		end
	end

	desc "Score songs"
	task :score do
		require "lib/database"
		Song.all.each do |song|
			Vote.score(song)
		end
	end

	desc "Add music from a folder"
	task :add, :folder do |t, args|
		require "mp3info"
		require "fileutils"
		require "securerandom"
		require "lib/database"
		require "lib/aacinfo"
		load_redis

		# songs require a User when added
		# create a import one so we don't mess with real user
		user = User.first(:username => "rake_import")
		unless user
			User.add(:username => "rake_import", :password => SecureRandom.hex(16))
			user = User.first(:username => "rake_import")
		end

		folder = args[:folder]
		Dir["#{folder}/**/*"].each do |path|
			ext = File.extname(path)[1..-1].downcase
			case ext
				when "mp3"
					mp3 = Mp3Info.open(path)
					tags = {
						:title => mp3.tag.title,
						:artist => mp3.tag.artist,
						:album => mp3.tag.album,
						:year => mp3.tag.year,
						:genre => mp3.tag.genre || mp3.tag.genre_s,
						:tracknum => mp3.tag.tracknum,
						:length => mp3.length
					}
				when "aac", "mp4", "m4a"
					aac = AACInfo.open(path)
					tags = {
						:title => aac.title,
						:artist => aac.artist,
						:album => aac.album,
						:year => aac.year,
						:genre => aac.genre,
						:tracknum => aac.track,
						:length => aac.length
					}
			end
			next unless tags[:title] and tags[:artist]
			tags[:album] = "Unknown Album" if tags[:album] == nil
			next if Song.first(:title => tags[:title], :artist => tags[:artist], :album => tags[:album])
			file = tags[:title].gsub(/[^A-Za-z0-9 ]/, '_') + "." + ext
			target = './music/' + tags[:artist].gsub(/[^A-Za-z0-9 ]/, '_') + '/' + tags[:album].gsub(/[^A-Za-z0-9 ]/, '_') + '/'
			FileUtils.mkdir_p(target)
			FileUtils.mv(path, target + file)
			s = Song.new
			s.attributes = {
				:path => target + file,
				:user => user,
				:created_at => Time.now,
				:updated_at => Time.now
			}.merge(tags)
			if s.save
				@redis.rpush "tasks", "normalize:#{target + file}"
			else
				FileUtils.rm(target + file)
			end
		end
	end

end

namespace :dev do
	task :start_web do
		`unicorn -c config/unicorn.rb -D`
	end

	task :restart_web do
		system("kill -USR2 `cat tmp/web.pid`")
	end

	task :stop_web do
		system("kill -QUIT `cat tmp/web.pid`")
	end
end

task :foo do
	puts "bar"
end

desc "Start Nginx"
task :server do
	system("sudo nginx -c /usr/local/etc/nginx/playr.conf")
end

# Pull latest version of Playr and reboot unicorn
# This will only work for changes to the Sinatra app
#  not updates to any other part of Playr
desc "Update Playr"
task :update do
	system("git pull")
	system("god restart playr-web")
end
