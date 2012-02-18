APP_DIR = File.expand_path(File.dirname(__FILE__) + '/../')
$: << APP_DIR
require "redis"
require "yaml"
require "lib/database"

`rm -f #{APP_DIR}/tmp/tasks.pid`
sleep(5)
File.open("#{APP_DIR}/tmp/tasks.pid", "w") do |file|
	file.puts Process.pid
end

def quit_process
	`rm -f #{APP_DIR}/tmp/tasks.pid`
	Process.exit!
end

Signal.trap("QUIT") do # god stop
	quit_process
end
Signal.trap("USR2") do # god restart
	@loop = false
	while @running
		sleep(0.5)
	end
	quit_process
end

config = YAML.load_file("#{APP_DIR}/config/config.yml")
redis = Redis.new(:host => config['redis']['host'], :port => config['redis']['port'])
@loop = true
@running = false

while @loop
	task = redis.blpop "tasks", 43200
	@running = true
	if task == nil
		# score songs since we haven't got a task in a while
		Song.all.each do |song|
			Vote.score(song)
		end
	else
		task = task.first
		task, *args = task.split(":")
		case task
		when "normalize"
			`aacgain -r -p -t -k "#{args.first}"`
		when "score"
			if args.first
				Vote.score(Song.get(args.first))
			else
				Song.all.each do |song|
					Vote.score(song)
				end
			end
		end
	end
	@running = false
end