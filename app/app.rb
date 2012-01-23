require 'sinatra/base'
require 'redis'
require 'rack-flash'
require 'fileutils'
require 'uri'
require 'json'
require 'digest'
require 'yaml'
require 'mp3info'
require 'haml'
require 'sass'
require 'coffee-script'

require './app/api'
require './lib/database'
require './lib/auth'
require './lib/aacinfo'
require './lib/lastfm'

module Playr
	class App < Sinatra::Base
		
		dir = File.dirname(File.expand_path(__FILE__))
		set :views, "#{dir}/../views"
		set :public_folder, "#{dir}/../public"
		set :static, true
		
		enable :sessions
		use Rack::Flash, :sweep => true

		use Rack::MethodOverride
		
		configure :development, :testing do
			
		end
		
		set :scss, { :style => :compressed, :debug_info => false }
		
		set(:auth) do |value|
			condition do
				unless @auth and @auth.is_valid?
					flash[:error] = "Must be logged in to see that page"
					redirect '/login'
				end
				if value == :admin and session[:user_id] != 1
					flash[:error] = "Insufficient privileges"
					redirect '/'
				end
			end
		end
		
		before do
			if flash[:error]
				@flash = 'humane.error("' + flash[:error].gsub('"', '\"') + '");'
			elsif flash[:notice]
				@flash = 'humane.success("' + flash[:notice].gsub('"', '\"') + '");'
			elsif flash[:info]
				@flash = 'humane.info("' + flash[:info].gsub('"', '\"') + '");'
			end
			if session[:user_id]
				@user = User.get(session[:user_id])
				@auth = Auth.new(@user.password, @user.secret, session, request.env)
			end
			@config = YAML.load_file("#{dir}/../config.yml")
			@redis = Redis.new(:host => @config['redis']['host'], :port => @config['redis']['port'])
			@lfm = Playr::Lastfm.new(@config['lastfm'], @redis)
		end

		helpers do
			def uri_encode(string)
				return URI.encode(string)
			end
			def uri_decode(string)
				#URI.unescape(string)
				return URI.decode(string)
			end
			def gravatar(email, size = 80)
				hash = Digest::MD5.hexdigest(email.downcase)
				"http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=mm"
			end
		end
		
		############
		## ROUTES ##
		############
		
		get "/application.css" do
			content_type "text/css"
			scss :'stylesheets/application'
		end
		
		get '/application.js' do
			content_type "text/javascript"
			coffee :'javascripts/application'
		end
		
		get "/", :auth => true do
			@title = "Home"
			haml :'application/index'
		end
		
		get "/browse", :auth => true do
			@title = "Browse"
			@artists = Song.artists
			@js = "var browse = new Browse();"
			haml :'browse/all'
		end
		
		get "/browse/artists", :auth => true do
			@title = "Artists"
			@js = "app.artists();"
			# pagination
			artists = Song.artists
			@total = artists.size
			@page = params[:page] ? params[:page].to_i : 1
			@per_page = 20
			@artists = {}
			offset = (@page - 1) * @per_page
			artists[(offset)..(offset + @per_page - 1)].each do |artist|
				image = nil
				@lfm.artist(artist.artist)["image"].each do |i|
					if image == nil and i['#text'] =~ /\d{3}.?\/\d+\.(png|jpg)$/
						image = i['#text']
					end
				end
				@artists[artist.artist] = image
			end
			return haml :'browse/artists', :layout => false if params[:ajax]
			haml :'browse/artists'
		end

		get "/browse/albums", :auth => true do
			@title = "Albums"
			@js = "app.albums();"
			# pagination
			albums = Song.albums
			@total = albums.size
			@page = params[:page] ? params[:page].to_i : 1
			@per_page = 16
			@albums = []
			offset = (@page - 1) * @per_page
			albums[(offset)..(offset + @per_page - 1)].each do |album|
				image = nil
				@lfm.album(album.album, album.artist)["image"].each do |i|
					if image == nil and i['#text'] =~ /\d{3}.?\/\d+\.(png|jpg)$/
						image = i['#text']
					end
				end
				image = 'http://placehold.it/174&text=No+Artwork+Found' if image == nil
				@albums << { :album => album.album, :artist => album.artist, :image => image }
			end
			return haml :'browse/albums', :layout => false if params[:ajax]
			haml :'browse/albums'
		end

		get "/artist/:artist", :auth => true do
			@title = params[:artist]
			@js = "app.artist();"
			@artist = @lfm.artist params[:artist]
			@image = 'http://placehold.it/350x250&text=Artist+image+not+found'
			@artist["image"].each { |i| @image = i["#text"] if i["size"] == "mega" }
			@albums = {}
			Song.albums(params[:artist]).each do |album|
				image = nil
				@lfm.album(album.album, params[:artist])["image"].each do |i|
					if image == nil and i["#text"] =~ /\d{3}.?\/\d+\.(png|jpg)$/
						image = i["#text"]
					end
				end
				image = 'http://placehold.it/174&text=No+Artwork+Found' if image == nil
				@albums[album.album] = image
			end
			@similar = {}
			@artist["similar"]["artist"].each do |artist|
				image = nil
				artist["image"].each do |i|
					if image == nil and i["#text"] =~ /\d{3}.?\/\d+\.(png|jpg)$/
						image = i["#text"]
					end
				end
				image = 'http://placehold.it/174&text=No+Artwork+Found' if image == nil
				@similar[artist["name"]] = image
			end
			haml :'info/artist'
		end

		get "/album/:album/:artist", :auth => true do
			@title = "#{params[:album]} by #{params[:artist]}"
			@album = @lfm.album(params[:album], params[:artist])
			@image = 'http://placehold.it/300x300&text=Artwork+not+found'
			@album["image"].each { |i| @image = i["#text"] if i["size"] == "extralarge" }
			@tracks = {}
			if @album["tracks"]["track"].class == Hash
				@tracks[1] = {
					:available => false,
					:name => @album["tracks"]["name"]
				}
			elsif @album["tracks"]["track"].class == Array
				@album["tracks"]["track"].each do |track|
					@tracks[track["@attr"]["rank"].to_i] = {
						:available => false,
						:name => track["name"]
					}
				end
			end
			Song.tracks(params[:artist], params[:album]).each do |track|
				@tracks[track.tracknum.to_i] = {
					:available => true,
					:id => track.id,
					:name => track.title
				}
			end
			haml :'info/album'
		end

		get "/track/:id", :auth => true do
			@song = Song.get(params[:id])
			halt 404, "track not found!" unless @song
			@title = @song.title
			@js = "app.track(#{@song.id});"
			@info = @lfm.track(@song.title, @song.artist)
			@image = 'http://placehold.it/300x300&text=Artwork+not+found'
			@lfm.album(@song.album, @song.artist)["image"].each { |i| @image = i["#text"] if i["size"] == "extralarge" }
			@likes = Vote.song(@song)
			@liked = Vote.likes(@song.id, @user.id)
			@queued = false
			haml :'info/track'
		end

		get "/track/:id/edit", :auth => true do
			
		end

		post "/track/:id", :auth => true do
			song = Song.get(params[:id])
			song.update(:title => params[:title], :artist => params[:artist], :album => params[:album], :tracknum => params[:tracknum], :year => params[:year], :genre => params[:genre], :updated_at => Time.now)
			flash[:notice] = "Track info updated"
			redirect "/track/#{params[:id]}"
		end

		delete "/track/:id", :auth => true do
			song = Song.get(params[:id])
			if song.destroy
				`rm -f #{song.path}`
				flash[:info] = "Song deleted"
				redirect '/'
			else
				flash[:error] = "Could not delete song"
				redirect "/track/#{params[:id]}"
			end
		end

		############
		## Upload ##
		############
		
		get "/upload", :auth => true do
			@title = "Upload"
			@js = "app.upload();"
			haml :'application/upload'
		end
		
		post "/upload", :auth => true do
			dir = './tmp/'
			if params[:qqfile].class == String
				name = params[:qqfile]
				string_io = request.body
				data_bytes = string_io.read
				path = File.join(dir, name)
				File.open(path, "w") do |f|
					f.write(data_bytes)
				end
			else
				name = params[:qqfile][:filename]
				path = File.join(dir, name)
				File.open(path, "wb") do |f|
					f.write(params[:qqfile][:tempfile].read)
				end
			end
			# normalize volume via aacgain
			unless `which aacgain`.empty?
				Dir.chdir(dir)
				`aacgain -r -p -t -k *.mp3 *.m4a *.mp4 *.aac`
				Dir.chdir("..")
			end
			
			ext = File.extname(path)[1..-1].downcase
			case ext
				when "mp3"
					mp3 = Mp3Info.open(path)
					unless mp3.tag.title
						FileUtils.rm(path)
						return { :error => true, :message => "No tags found for #{name}" }.to_json
					end
					tags = {
						:title => mp3.tag.title,
						:artist => mp3.tag.artist,
						:album => mp3.tag.album,
						:year => mp3.tag.year,
						:genre => mp3.tag.genre || mp3.tag.genre_s,
						:tracknum => mp3.tag.tracknum,
						:length => mp3.length
					}
				when "aac", "mp4", "m4a"
					aac = AACInfo.open(path)
					unless aac.title
						FileUtils.rm(path)
						return { :error => true, :message => "No tags found for #{name}" }.to_json
					end
					tags = {
						:title => aac.title,
						:artist => aac.artist,
						:album => aac.album,
						:year => aac.year,
						:genre => aac.genre,
						:tracknum => aac.track,
						:length => aac.length
					}
				else
					FileUtils.rm(path)
					return { :error => true, :message => "Not a supported filetype. Supported filetypes are mp3, m4a, aac, mp4." }.to_json
			end
			if tags.empty?
				FileUtils.rm(path)
				return { :error => true, :message => "Ran into error uploading #{name}" }.to_json
			end
			tags[:album] = "Unknown Album" if tags[:album] == nil
			if Song.first(:title => tags[:title], :artist => tags[:artist], :album => tags[:album] )
				FileUtils.rm(path)
				return { :error => true, :message => "Song already exists." }.to_json
			end
			# move file
			file = tags[:title].gsub(/[^A-Za-z0-9 ]/, '_') + "." + ext
			target = './music/' + tags[:artist].gsub(/[^A-Za-z0-9 ]/, '_') + '/' + tags[:album].gsub(/[^A-Za-z0-9 ]/, '_') + '/'
			FileUtils.mkdir_p(target) unless File.exists?(target)
			FileUtils.mv(path, target + file)
			# add to db
			s = Song.new
			s.attributes = {
				:path => target + file,
				:user => @user,
				:created_at => Time.now,
				:updated_at => Time.now
			}.merge(tags)
			
			if s.save
				return { :success => true }.to_json
			else
				FileUtils.rm(target + file)
				return { :error => true, :message => "Could not save #{name}" }.to_json
			end
		end
		
		##################
		## Login/Logout ##
		##################
		
		get "/login" do
			@title = "Login"
			haml :'application/login'
		end
		
		post "/login" do
			username = params[:username]
			password = params[:password]
			user = User.first(:username => username)
			unless user
				flash[:error] = "Invalid username/password combination"
				redirect '/login'
			end
			@auth = Auth.new(user.password, user.secret, session, request.env)
			if @auth.validate(password)
				session[:user_id] = user.id
				flash[:info] = "Welcome back #{user.name}"
				redirect '/'
			else
				flash[:error] = "Invalid username/password combination"
				redirect '/login'
			end
		end
		
		get "/logout", :auth => true do
			@auth.invalidate
			session.clear
			redirect '/login'
		end
	end
end