APP_DIR = File.expand_path(File.dirname(__FILE__))

God.watch do |w|
	w.name = "playr-web"
	w.group = "playr"
	w.interval = 30.seconds

	w.start = "unicorn -c #{APP_DIR}/config/unicorn.rb -D"
	w.stop = "kill -QUIT `cat #{APP_DIR}/tmp/web.pid`"
	w.restart = "kill -USR2 `cat #{APP_DIR}/tmp/web.pid`"
	
	w.start_grace = 10.seconds
	w.restart_grace = 10.seconds
	w.pid_file = "#{APP_DIR}/tmp/web.pid"
	w.behavior(:clean_pid_file)

	w.start_if do |start|
		start.condition(:process_running) do |c|
			c.interval = 5.seconds
			c.running = false
		end
	end

	w.restart_if do |restart|
		restart.condition(:memory_usage) do |c|
			c.above = 150.megabytes
			c.times = [3, 5]
		end

		restart.condition(:cpu_usage) do |c|
			c.above = 50.percent
			c.times = 5
		end
	end

	w.lifecycle do |on|
		on.condition(:flapping) do |c|
			c.to_state = [:start, :restart]
			c.times = 5
			c.within = 5.minute
			c.transition = :unmonitored
			c.retry_in = 10.minutes
			c.retry_times = 5
			c.retry_within = 2.hours
		end
	end
end

God.watch do |w|
	w.name = "playr-music"
	w.group = "playr"
	w.interval = 30.seconds

	w.start = "ruby #{APP_DIR}/lib/playr.rb"
	w.stop = "kill -QUIT `cat #{APP_DIR}/tmp/music.pid`"
	w.restart = "kill -USR2 `cat #{APP_DIR}/tmp/music.pid`"
	
	w.start_grace = 10.seconds
	w.restart_grace = 10.seconds
	w.pid_file = "#{APP_DIR}/tmp/music.pid"
	w.behavior(:clean_pid_file)

	w.start_if do |start|
		start.condition(:process_running) do |c|
			c.interval = 5.seconds
			c.running = false
		end
	end

	w.restart_if do |restart|
		restart.condition(:memory_usage) do |c|
			c.above = 150.megabytes
			c.times = [3, 5]
		end

		restart.condition(:cpu_usage) do |c|
			c.above = 50.percent
			c.times = 5
		end
	end

	w.lifecycle do |on|
		on.condition(:flapping) do |c|
			c.to_state = [:start, :restart]
			c.times = 5
			c.within = 5.minute
			c.transition = :unmonitored
			c.retry_in = 10.minutes
			c.retry_times = 5
			c.retry_within = 2.hours
		end
	end
end

# God.watch do |w|
# 	w.name = "playr_socket"
# 	w.group = "playr"
# end