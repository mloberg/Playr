module Playr
	class App < Sinatra::Base
		set(:auth) do |value|
			condition do
				unless @auth and @auth.is_valid?
					return error_response "Must be logged in!"
				end
			end
		end

		def error_response(msg)
			{ :error => true, :message => msg }.to_json
		end

		def api_response(resp)
			resp.to_json
		end

		get "/api/info" do
			case params[:method]
				when 'artist'
					return error_response "Missing artist." unless params[:artist]
					api_response @info.artist(params[:artist])
				when 'album'
					return error_response "Missing album and artist." unless params[:artist] and params[:album]
					api_response @info.album(params[:album], params[:artist])
				when 'track'
					return error_response "Missing track and artist." unless params[:artist] and params[:track]
					api_response @info.track(params[:track], params[:artist])
				else
					error_response "Missing parameters"
			end
		end

		get "/api/get" do
			case params[:method]
				when 'artists'
					artists = []
					Song.artists.each do |artist|
						artists << artist.artist
					end
					api_response artists
				when 'albums'
					albums = []
					Song.albums(params[:artist]).each do |album|
						albums << { :artist => album.artist, :album => album.album }
					end
					api_response albums
				when 'tracks'
					return error_response "Missing artist." unless params[:artist]
					tracks = []
					Song.tracks(params[:artist], params[:album]).each do |track|
						tracks << track.to_h
					end
					api_response tracks
				else
					error_response "Missing parameters"
			end
		end
		
		get "/api/playing" do
			
		end
		
		get "/api/volume" do
			
		end
		
		post "/api/queue" do # auth
		
		end
		
		post "/api/like", :auth => true do
			return error_response "Missing data" unless params[:song]
			Vote.up(params[:song], @user.id)
			{ :success => true, :message => "Liked song" }.to_json
		end
		
		post "/api/dislike", :auth => true do
			return error_response "Missing data" unless params[:song]
			Vote.down(params[:song], @user.id)
			{ :success => true, :message => "Disliked song" }.to_json
		end
		
		post "/api/play" do # auth
		
		end
		
		post "/api/pause" do # auth
			
		end
		
		post "/api/next" do # auth
		
		end
		
		post "/api/skip" do # auth
		
		end
		
		post "/api/volume" do # auth
			
		end
	end
end