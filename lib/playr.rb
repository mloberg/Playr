APP_DIR = File.expand_path(File.dirname(__FILE__) + '/../')
$: << APP_DIR
# require "lib/database"
# require "lib/worker"

File.open("#{APP_DIR}/tmp/music.pid", "w") do |file|
	file.puts Process.pid
end

def quit_process
	`rm -f #{APP_DIR}/tmp/music.pid`
	Process.exit!
end

Signal.trap("QUIT") do # god stop
	quit_process
end
Signal.trap("USR2") do # god restart
	quit_process
end

loop do
	puts "loop"
	sleep(1)
end

# auto-play thread
# loop do
# 	if Playr::Worker.playing? or Playr::Worker.paused?
# 		sleep(1)
# 	else
# 		queued = SongQueue.first
# 		if queued
# 			song = queued.song
# 			queued.destroy
# 		else
# 			sql = "SELECT `id` FROM `songs` AS r1 JOIN(SELECT ROUND(RAND() * (SELECT MAX(id) FROM `songs`)) AS 'tmpid') AS r2 WHERE r1.id >= r2.tmpid AND vote > 300"
# 			# no christmas music
# 			time = Time.new
# 			week = ((time.day - (time.wday + 1)) / 7) + 1
# 			unless (time.month == 11 and ((week == 4 and time.wday >= 4) or week > 4)) or (time.month == 12 and time.day < 26)
# 				sql << " AND (`genre` != 'holiday' AND `genre` != 'christmas' AND `genre` NOT LIKE 'season%')"
# 			end
# 			sql << " ORDER BY r1.id ASC LIMIT 1"
# 			tmpid = repository(:default).adapter.select(sql).pop
# 			song = Song.get(tmpid)
# 		end

# 		if song
# 			History.create(:song => song, :played_at => Time.now)
# 			# play the song
# 			# update websocket
# 			# update Last.fm
# 		else
# 			sleep(1)
# 		end
# 	end
# end