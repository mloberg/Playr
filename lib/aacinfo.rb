class AACInfo

	def self.open(file)
		self.new(file)
	end
	
	def initialize(file)
		raise "No such file" unless File.exist?(file)
		@file = file
		@tags = {}
		parse_info
	end
	
	def method_missing(id)
		key = id.to_sym
		return @tags[key] if @tags.has_key? key
		nil
	end
	
	private
	
	def parse_info
		# get info with faad
		info = `faad -i "#{@file}" 2>&1`.split(@file + " file info:\n\n").last.split("\n")
		
		# get the track length
		@tags[:length] = info.shift[/\d+\.\d{1,3}/]
		
		# there is a blank line, delete it
		info.shift
		
		# go through each tag and save it to the instance variable
		info.each do |tag|
			key, *value = tag.split(": ")
			@tags[key.to_sym] = value.join(": ")
		end
	end

end