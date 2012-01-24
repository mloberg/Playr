$: << File.expand_path(File.dirname(__FILE__) + '/../')
require "socket"
require "lib/database"
#require "lib/worker"

class Worker
	def self.playing?
		false
	end
	def self.paused?
		false
	end
end

# auto-play thread
Thread.new do
	loop do
		if Worker.playing? or Worker.paused?
			sleep(1)
		else
			queued = SongQueue.first
			if queued
				song = queued.song
				queued.destroy
			else
				sql = "SELECT `id` FROM `songs` AS r1 JOIN(SELECT ROUND(RAND() * (SELECT MAX(id) FROM `songs`)) AS 'tmpid') AS r2 WHERE r1.id >= r2.tmpid AND vote > 300"
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
				puts song.title
				sleep(5)
			else
				sleep(1)
			end
		end
	end
end

## listen for commands

server = TCPServer.open(2000)
loop do
	client = server.accept
	client.puts(Time.now.ctime)
	client.puts "Closing the connection. Bye!"
	client.close
end

#### Commands
###
## play
## pause
## stop
## volume
## 