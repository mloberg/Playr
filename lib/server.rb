class Server

	def self.websocket(update_key)
		Signal.trap("INT") { Process.exit! }
		Signal.trap("TERM") { Process.exit! }
		Signal.trap("VTALRM") { Process.exit! }
		server = WebSocketServer.new(:port => 10081, :accepted_domains => ["*"])
		web_connections = []
		desk_connections = []

		server.run do |ws|
			if ws.path == "/"
				begin
					ws.handshake
					que = Queue.new
					web_connections.push(que)
					thread = Thread.new do
						while true
							ws.send que.pop
						end
					end
					while true
						sleep 1
					end
				ensure
					web_connections.delete(que)
					thread.terminate if thread
				end
			elsif ws.path == "/notify"
				begin
					ws.handshake
					que = Queue.new
					desk_connections.push(que)
					thread = Thread.new do
						while true
							ws.send que.pop
						end
					end
					while true
						sleep 1
					end
				ensure
					desk_connections.delete(que)
					thread.terminate if thread
				end
			elsif ws.path == "/update?key=#{update_key}"
				ws.handshake
				while data = ws.receive
					for conn in web_connections
						conn.push data
					end
				end
			elsif ws.path == "/notify?key=#{update_key}"
				ws.handshake
				while data = ws.receive
					for conn in desk_connections
						conn.push data
					end
				end
			else
				ws.handshake("404 Not Found")
			end
		end
	end

	def self.music(update_key)
		while true
			Signal.trap("INT") {
				Playr.stop
				Process.exit!
			}
			Signal.trap("TERM") {
				Playr.stop
				Process.exit!
			}
			Signal.trap("VTALRM") {
				Playr.stop
				Process.exit!
			}
			if Playr.paused? or Playr.playing? or Song.all.length == 0
				sleep(1)
			else
				next_song = Playr.next_song
				break if next_song == nil
				next_song.adjust!(:plays => 1)
				History.create(:song => next_song, :played_at => Time.now)
				Playr.play(next_song.path)
				# web users
				update = WebSocket.new("ws://127.0.0.1:10081/update?key=#{update_key}")
				update.send "Now playing <strong>#{next_song.title}</strong> by <strong>#{next_song.artist}</strong>"
				update.close
				# growl users
				growl = WebSocket.new("ws://127.0.0.1:10081/notify?key=#{update_key}")
				growl.send({ :title => "Playr Now Playing", :message => "#{next_song.title} by #{next_song.artist}" }.to_json)
				if LASTFM_SESSION
					$lastfm.update({
						:album => next_song.album,
						:track => next_song.title,
						:artist => next_song.artist
					})
				end
			end
		end
	end

end