require 'httparty'
require 'digest/md5'
require 'json'
require 'redis'

module Playr
	class Info
	
		include HTTParty
		base_uri "http://ws.audioscrobbler.com/2.0/"
		default_params :format => 'json'
		format :json
		
		def initialize(options)
			@options = options
			@redis = Redis.new(:host => options['redis']['host'], :port => options['redis']['port'])
			self.class.default_params :api_key => options['lastfm']['api_key']
		end
		
		def q(method, params)
			params[:method] = method
			self.class.get('', :query => params)
		end
		
		def artist(artist)
			if @redis.hexists "artist", artist
				JSON.parse(@redis.hget "artist", artist)
			else
				data = self.q('artist.getInfo', { :artist => artist, :autocorrect => 1 })["artist"]
				@redis.hset "artist", artist, data.to_json
				data
			end
		end
		
		def album(album, artist)
			key = "#{artist}:#{album}"
			if @redis.hexists "album", key
				JSON.parse(@redis.hget "album", key)
			else
				data = self.q('album.getInfo', { :album => album, :artist => artist, :autocorrect => 1 })["album"]
				@redis.hset "album", album, data.to_json
				data
			end
		end
	
	end
end