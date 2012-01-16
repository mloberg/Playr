require 'httparty'
require 'json'
require 'digest/md5'

class LastFM

	include HTTParty
	base_uri "http://ws.audioscrobbler.com/2.0/"
	default_params :format => 'json'
	format :json
	
	def initialize(api_key, secret)
		@api_key = api_key
		@secret = secret
		self.class.default_params :api_key => api_key
	end
	
	def session=(sk)
		@session = sk
	end
	
	def q(method, params)
		params[:method] = method
		self.class.get('', :query => params)
	end
	
	def artist(artist)
		self.q('artist.getInfo', { :artist => artist, :autocorrect => 1 })["artist"]
	end
	
	def album(album, artist)
		self.q('album.getInfo', { :album => album, :artist => artist, :autocorrect => 1 })["album"]
	end
	
	def album_artwork(album, artist)
		resp = self.album(album, artist)
		return nil unless resp
		resp["image"].each do |i|
			return i["#text"] if i["size"] == "large"
		end
		nil
	end
	
	def track(track, artist)
		self.q('track.getInfo', { :artist => artist, :track => track, :autocorrect => 1 })["track"]
	end
	
	def update(params)
		params[:timestamp] = Time.now.to_i.to_s
		params[:method] = 'track.scrobble'
		params[:sk] = @session
		params[:api_sig] = sign(params)
		self.class.post('', :query => params)
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
	
	def sign(params)
		params[:api_key] = @api_key
		str_to_sign = ''
		params.keys.sort.each { |key| str_to_sign << key.to_s + params[key] }
		str_to_sign << @secret
		Digest::MD5.hexdigest(str_to_sign)
	end

end