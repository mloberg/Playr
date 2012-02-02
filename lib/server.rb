APP_DIR = File.expand_path(File.dirname(__FILE__) + '/../')
$: << APP_DIR
require "lib/web_socket"
require "thread"
require "yaml"
require "json"

`rm -f #{APP_DIR}/tmp/ws.pid`
sleep(5)
File.open("#{APP_DIR}/tmp/ws.pid", "w") do |file|
	file.puts Process.pid
end

def quit_process
	`rm -f #{APP_DIR}/tmp/ws.pid`
	Process.exit!
end

Signal.trap("QUIT") do # god stop
	quit_process
end
Signal.trap("USR2") do # god restart
	quit_process
end

config = YAML.load_file("#{APP_DIR}/config/config.yml")

server = WebSocketServer.new(:port => 10081, :accepted_domains => ["*"])
web_conn = []
desk_conn = []

server.run do |ws|
	if ws.path == "/"
		begin
			ws.handshake
			q = Queue.new
			web_conn.push(q)
			thread = Thread.new do
				while true
					ws.send q.pop
				end
			end
			while true
				sleep 1
			end
		ensure
			web_conn.delete(q)
			thread.terminate if thread
		end
	elsif ws.path == "/notify"
		begin
			ws.handshake
			q = Queue.new
			desk_conn.push(q)
			thread = Thread.new do
				while true
					ws.send q.pop
				end
			end
			while true
				sleep 1
			end
		ensure
			desk_conn.delete(q)
			thread.terminate if thread
		end
	elsif ws.path == "/update?key=#{config["ws_key"]}"
		ws.handshake
		while data = ws.receive
			song = JSON.parse(data)
			for conn in web_conn
				conn.push "Now playing <strong>#{song["title"]}</strong> by <strong>#{song["artist"]}</strong>"
			end
			for conn in desk_conn
				conn.push({ :title => "Playr Now Playing", :message => "#{song["title"]} by #{song["artist"]}" }.to_json)
			end
		end
	else
		ws.handshake("404 Not Found")
	end
end