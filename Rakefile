APP_DIR = File.expand_path(File.dirname(__FILE__))
$: << APP_DIR
require "rake"

def load_config
	require "yaml"
	@config = YAML.load_file("#{APP_DIR}/config/config.yml")
end

desc "Normalize all audio files"
task :normalize do
	# normalize all audio files by adding them as a task to redis
	require "redis"
	load_config
	redis = Redis.new(:host => @config['redis']['host'], :port => @config['redis']['port'])
	files = Dir.glob("music/*/*/*")
	files.each do |f|
		redis.rpush "tasks", "normalize:./#{f}"
	end
end

# desc "Add music"
# task :add, :folder do |t, args|
# 	folder = args[:folder]
# end

desc "Score songs"
task :score do
	require "lib/database"
	Song.all.each do |song|
		Vote.score(song)
	end
end

# Pull latest version of Playr and reboot unicorn
# This will only work for changes to the Sinatra app
#  not updates to any other part of Playr
desc "Update Playr"
task :update do
	system("git pull")
	system("god restart playr-web")
end
