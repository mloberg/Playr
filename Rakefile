APP_DIR = File.expand_path(File.dirname(__FILE__))
$: << APP_DIR
require "rake"

def load_config
	require "yaml"
	@config = YAML.load_file("#{APP_DIR}/config/config.yml")
end

def load_redis
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

# Moving ./playr commands over here.
# I'll need to set a default task to list commands.
namespace :playr do

	desc "Start Playr and its sub-processes"
	task :start do
		# make sure god is running
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
		require "redis"
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

	# desc "Add music from a folder"
	# task :add, :folder do |t, args|
	# 	folder = args[:folder]
	# end

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
