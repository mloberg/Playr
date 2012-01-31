APP_DIR = File.expand_path(File.dirname(__FILE__) + '/../')
$: << APP_DIR
require "lib/database"
require "lib/worker"

`rm -f #{APP_DIR}/tmp/music.pid`
File.open("#{APP_DIR}/tmp/music.pid", "w") do |file|
	file.puts Process.pid
end

def quit_process
	`rm -f #{APP_DIR}/tmp/music.pid`
	Process.exit!
end

Signal.trap("QUIT") do # god stop
	`killall afplay`
	quit_process
end
Signal.trap("USR2") do # god restart
	quit_process
end

# auto-play thread
loop do
	if Playr::Worker.playing? or Playr::Worker.paused?
		sleep(1)
	else
		queued = SongQueue.first(:order => [:created_at.asc])
		if queued
			song = queued.song
			queued.destroy
		else
			sql = "SELECT `id` FROM `songs` AS r1 JOIN(SELECT ROUND(RAND() * (SELECT MAX(id) FROM `songs`)) AS 'tmpid') AS r2 WHERE r1.id >= r2.tmpid AND r1.vote > 300 AND (r1.last_played < '#{(Time.now - 86400).strftime("%Y-%m-%d %H:%M:%S")}' OR r1.last_played is null)"
			# no christmas music
			time = Time.new
			week = ((time.day - (time.wday + 1)) / 7) + 1
			unless (time.month == 11 and ((week == 4 and time.wday >= 4) or week > 4)) or (time.month == 12 and time.day < 26)
				sql << " AND (`genre` != 'holiday' AND `genre` != 'christmas' AND `genre` NOT LIKE 'season%')"
			end
			sql << " ORDER BY r1.id ASC LIMIT 1"
			tmpid = repository(:default).adapter.select(sql).pop
			song = Song.get(tmpid)
		end

		if song
			History.create(:song => song, :played_at => Time.now)
			song.update(:last_played => Time.now)
			song.adjust!(:plays => 1)
			# update websocket
			# update Last.fm
			song_path = song.path.to_s
			path = APP_DIR + song_path[1..song_path.length]
			system("afplay -q 1 '#{path}'")
		else
			sleep(1)
		end
	end
end