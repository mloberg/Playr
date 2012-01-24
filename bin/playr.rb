dir = File.expand_path(File.dirname(__FILE__) + '/../')
# $: << dir
# require "socket"
# require "lib/database"
# require "lib/worker"

loop do
	# Signal.trap("SIGTERM") do
	# 	puts "stopping"
	# end
	puts "running"
	sleep(1)
end

# auto-play thread
# Thread.new do
# 	loop do
# 		if Playr::Worker.playing? or Playr::Worker.paused?
# 			sleep(1)
# 		else
# 			queued = SongQueue.first
# 			if queued
# 				song = queued.song
# 				queued.destroy
# 			else
# 				sql = "SELECT `id` FROM `songs` AS r1 JOIN(SELECT ROUND(RAND() * (SELECT MAX(id) FROM `songs`)) AS 'tmpid') AS r2 WHERE r1.id >= r2.tmpid AND vote > 300"
# 				# no christmas music
# 				time = Time.new
# 				week = ((time.day - (time.wday + 1)) / 7) + 1
# 				unless (time.month == 11 and ((week == 4 and time.wday >= 4) or week > 4)) or (time.month == 12 and time.day < 26)
# 					sql << " AND (`genre` != 'holiday' AND `genre` != 'christmas' AND `genre` NOT LIKE 'season%')"
# 				end
# 				sql << " ORDER BY r1.id ASC LIMIT 1"
# 				tmpid = repository(:default).adapter.select(sql).pop
# 				song = Song.get(tmpid)
# 			end

# 			if song
#				History.create(:song => song, :played_at => Time.now)
# 				# play the song
# 				# update websocket
# 				# update Last.fm
# 			else
# 				sleep(1)
# 			end
# 		end
# 	end
# end

## listen for commands
# server = TCPServer.open(2009)
# loop do
# 	Thread.start(server.accept) do |client|
# 		while command = client.gets
# 			if command.split(":").size != 1
# 				command, *options = command.split(":")
# 			end
# 			case command
# 				when 'play'
# 					if Playr::Worker.paused?
# 						`rm -f #{dir}/tmp/pause`
# 					end
# 				when 'pause'
# 					if Playr::Worker.paused?
# 						`rm -f #{dir}/tmp/pause`
# 					else
# 						`touch #{dir}/tmp/pause`
# 						`killall afplay > /dev/null 2>&1`
# 					end
# 				when 'skip'
# 					if Playr::Worker.paused?
# 						`killall afplay > /dev/null 2>&1`
# 					end
# 				when 'stop'
# 					`touch #{dir}/tmp/pause`
# 					`killall afplay > /dev/null 2>&1`
# 				when 'volume'
# 					volume = options.first
# 					system("osascript -e 'set volume output volume #{volume}' 2>/dev/null")
# 			end
# 			client.close
# 		end
# 	end
# end

# #### Commands
# ###
# ## play
# ## pause
# ## skip
# ## volume:vol
# ## 