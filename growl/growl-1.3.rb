$: << File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'json'
require 'yaml'
require 'ruby_gntp'
require 'web_socket'

config_file = File.expand_path(File.dirname(__FILE__)) + "/config.yml"

if not FileTest.exist? config_file
	puts "No config file found. Exiting..."
	Process.exit
end

config = YAML::load_file config_file

growl = GNTP.new("Playr Updater")
growl.register({ :notifications => [{
	:name => "notify",
	:enabled => true
}]})

while true
	begin
		client = WebSocket.new("ws://#{config["host"]}:10081/notify")
		while data = client.receive
			data = JSON.parse(data)
			growl.notify({
				:name => "notify",
				:title => data["title"],
				:text => data["message"]
			})
		end
	rescue
		sleep(1)
		retry
	end
end