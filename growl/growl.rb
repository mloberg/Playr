$: << File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'json'
require 'yaml'
require 'ruby-growl'
require 'web_socket'

if not FileTest.exist? 'config.yml'
	puts "No config file found. Exiting..."
	Process.exit
end

config = YAML::load_file 'config.yml'

growl = Growl.new "127.0.0.1", "playr-update", ["playr-update Notification"]

while true
	begin
		client = WebSocket.new("ws://#{config["host"]}:10081/notify")
		while data = client.receive
			data = JSON.parse(data)
			growl.notify "playr-update Notification", data["title"], data["message"]
		end
	rescue
		sleep(1)
		retry
	end
end