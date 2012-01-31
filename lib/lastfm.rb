require 'httparty'
require 'digest/md5'
require 'json'
require 'redis'

module Playr
	class Lastfm
	
		include HTTParty
		base_uri "http://ws.audioscrobbler.com/2.0/"
		default_params :format => 'json'
		format :json
		
		def initialize(options, redis = nil)
			@options = options
			@redis = redis
			self.class.default_params :api_key => @options['api_key']
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
				@redis.hset "album", key, data.to_json
				data
			end
		end
		
		def track(track, artist)
			key = "#{artist}:#{track}"
			if @redis.hexists "track", key
				JSON.parse(@redis.hget "track", key)
			else
				data = self.q('track.getInfo', { :artist => artist, :track => track, :autocorrect => 1 })["track"]
				@redis.hset "track", key, data.to_json
				data
			end
		end
		
		#############################
		## Last.fm Scrobbe Methods ##
		#############################
		
		def sign(params)
			params[:api_key] = @options['api_key']
			str_to_sign = ''
			params.keys.sort.each { |key| str_to_sign << key.to_s + params[key] }
			str_to_sign << @options['secret']
			Digest::MD5.hexdigest(str_to_sign)
		end
		
		def auth_token
			params = { :method => 'auth.getToken' }
			params[:api_sig] = sign(params)
			self.class.post('', :query => params)["token"]
		end
		
		def auth_session(token)
			params = { :method => 'auth.getSession', :token => token }
			params[:api_sig] = sign(params)
			resp = self.class.post('', :query => params)
			return resp["session"]["key"] if resp["session"]["key"]
			nil
		end
		
		def update(params)
			params[:timestamp] = Time.now.to_i.to_s
			params[:method] = 'track.scrobble'
			params[:sk] = @options['session']
			params[:api_sig] = sign(params)
			self.class.post('', :query => params)
		end
	
	end
end