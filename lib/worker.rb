module Playr
	class Worker

		def self.playing?
			`ps aux | grep afplay | grep -v grep | wc -l | tr -d ' '`.chomp != "0"
		end

		def self.paused?
			File.exists?("#{APP_DIR}/tmp/pause")
		end

		def self.volume
			vol = `osascript -e 'get output volume of (get volume settings)'`
			vol.to_i
		end
		
	end
end