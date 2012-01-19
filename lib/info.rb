require 'redis'
require 'json'

module Playr
	class Info
	
		def initialize(lastfm, host, port = 6379)
			@lastfm = lastfm
			@redis = Redis.new(:host => host, :port => port)
		end
		
		def artist(artist)
			if @redis.hexists "artist:info", artist
				data = @redis.hget "artist:info", artist
				JSON.parse(data)
			else
				data = @lastfm.artist artist
				@redis.hset "artist:info", artist, data.to_json
				data
			end
		end
	
	end
end