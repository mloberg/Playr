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
					api_response @lfm.artist(params[:artist])
				when 'album'
					return error_response "Missing album and artist." unless params[:artist] and params[:album]
					api_response @lfm.album(params[:album], params[:artist])
				when 'track'
					return error_response "Missing track and artist." unless params[:artist] and params[:track]
					api_response @lfm.track(params[:track], params[:artist])
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
			if Playr::Worker.playing?
				api_response({ :playing => true, :song => @playing = History.last.song.to_h })
			else
				api_response({ :playing => false })
			end
		end

		get "/api/now-playing", :auth => true do
			if Playr::Worker.playing?
				@song = History.last.song
				haml :'partials/now-playing', :layout => false
			end
		end
		
		get "/api/volume" do
			api_response @volume
		end
		
		post "/api/like", :auth => true do
			return error_response "Missing data" unless params[:song]
			Vote.up(params[:song], @user.id)
			api_response({ :success => true, :message => "Liked song" })
		end
		
		post "/api/dislike", :auth => true do
			return error_response "Missing data" unless params[:song]
			Vote.down(params[:song], @user.id)
			api_response({ :success => true, :message => "Disliked song" })
		end
		
		post "/api/start-stop", :auth => true do
			`#{APP_DIR}/playr pause`
			api_response({ :success => true, :paused => Playr::Worker.paused? })
		end
		
		post "/api/next", :auth => true do
			`#{APP_DIR}/playr skip`
		end
		
		post "/api/skip", :auth => true do
			# remove song from queue
			return error_response "Missing data" unless params[:id]
			q = SongQueue.first(:song => Song.get(params[:id]))
			if q.destroy
				api_response({ :success => true })
			else
				error_response "Could not remove track from queue"
			end
		end
		
		post "/api/volume", :auth => true do
			return error_response "Missing data" unless params[:level]
			`#{APP_DIR}/playr volume #{params[:level]}`
		end
	end
end