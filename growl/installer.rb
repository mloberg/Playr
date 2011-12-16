require 'fileutils'

puts "Do you want to install the Growl plugin for Playr?"
loop do
	print "[y/n]> "
	resp = STDIN.gets.chomp
	if resp =~ /y|Y|yes/
		break;
	elsif resp =~ /n|N|no/
		puts "Goodbye then."
		Process.exit
	else
		redo
	end
end

puts "Are you using Growl 1.3? If you installed it through the App Store, you are using 1.3."
print "[y/n]> "

if STDIN.gets.chomp =~ /y|Y|yes/
	puts "Installing the ruby_gntp gem."
	puts "Does gem need admin privileges (you need to type sudo gem)?"
	print "[y/n]> "
	if STDIN.gets.chomp =~ /y|Y|yes/
		system("sudo gem install json daemons ruby_gntp")
	else
		system("gem install json daemons ruby_gntp")
	end
	FileUtils.mkdir_p('/usr/local/var/playr')
	FileUtils.cp('growl-1.3.rb', '/usr/local/var/playr/growl.rb')
else
	puts "Installing the ruby-growl gem."
	puts "Does gem need admin privileges (you need to type sudo gem)?"
	if STDIN.gets.chomp =~ /y|Y|yes/
		system("sudo gem install json daemons ruby-growl")
	else
		system("gem install json daemons ruby-growl")
	end
	FileUtils.mkdir_p('/usr/local/var/playr')
	FileUtils.cp('growl.rb', '/usr/local/var/playr/growl.rb')
	puts "\nYou will need to set a couple of Growl config options."
	puts "First open up Growl preferences (under System Preferences)."
	puts "Under Network check 'Listen for incoming notifications' and 'Allow remote application registration'. Do not set a password."
	puts "Once you have done that, you may have to restart Growl for it to take effect."
end

puts "What is the host of your Playr install?"
print "> "
host = STDIN.gets.chomp
File.open('/usr/local/var/playr/config.yml', 'w') { |f| f.write("host: #{host}") }

FileUtils.cp('web_socket.rb', '/usr/local/var/playr/web_socket.rb')

FileUtils.cp('daemon.rb', '/usr/local/bin/growl-playr')
`chmod +x /usr/local/bin/growl-playr`

puts "Autoload on login?"
print "[y/n]> "
if STDIN.gets.chomp =~ /y|Y|yes/
	home = File.expand_path('~')
	FileUtils.mkdir_p("#{home}/Library/LaunchAgents")
	FileUtils.cp('com.playr.growl.plist', "#{home}/Library/LaunchAgents/com.playr.growl.plist")
	`launchctl load ~/Library/LaunchAgents/com.playr.growl.plist`
	puts "Growl-playr has started and will autoload on login."
end

puts "Congratulations, you have installed the Growl plugin for Playr."
puts "Usage: growl-playr {start|stop|restart|status}"