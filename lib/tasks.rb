APP_DIR = File.expand_path(File.dirname(__FILE__) + '/../')
require "redis"
require "yaml"

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
	quit_process
end

config = YAML.load_file("#{APP_DIR}/config/config.yml")
redis = Redis.new(:host => config['redis']['host'], :port => config['redis']['port'])

loop do
	task = redis.blpop "tasks", 0
	task = task.first
	task, *args = task.split(":")
	case task
	when "normalize"
		`aacgain -r -p -t -k "#{args.first}"`
	end
end