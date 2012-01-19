require 'sinatra/base'
require 'rack-flash'
require 'fileutils'
require 'json'
require 'yaml'
require 'mp3info'
require 'haml'
require 'sass'
require 'coffee-script'

require './app/database'
require './app/auth'
require './lib/aacinfo'
require './lib/lastfm'
require './lib/info'

module Playr
	class App < Sinatra::Base
		
		dir = File.dirname(File.expand_path(__FILE__))
		set :views, "#{dir}/../views"
		set :public_folder, "#{dir}/../public"
		set :static, true
		
		enable :sessions
		use Rack::Flash, :sweep => true
		
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
				session[:flash] = 'humane.error("' + flash[:error].gsub('"', '\"') + '");'
			elsif flash[:notice]
				session[:flash] = 'humane.success("' + flash[:notice].gsub('"', '\"') + '");'
			elsif flash[:info]
				session[:flash] = 'humane.info("' + flash[:info].gsub('"', '\"') + '");'
			end
			if session[:user_id]
				@user = User.get(session[:user_id])
				@auth = Auth.new(@user.password, @user.secret, session, request.env)
			end
			@config = YAML.load_file("#{dir}/../config.yml")
			@lastfm = LastFM.new(@config['lfm_key'], @config['lfm_secret'])
			@info = Playr::Info.new(@lastfm, @config['redis_host'])
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
			render = coffee :'javascripts/application'
			render.gsub!(/\/\/ @flash;/, session[:flash] || '')
			session[:flash] = nil
			render.gsub!(/\/\/ @js;/, session[:js] || '')
			session[:js] = nil
			render
		end
		
		get "/", :auth => true do
			@title = "Home"
			haml :'application/index'
		end
		
		get "/browse", :auth => true do
			@title = "Browse"
			@artists = Song.artists
			haml :'browse/all'
		end
		
		############
		## Upload ##
		############
		
		get "/upload", :auth => true do
			@title = "Upload"
			session[:js] = "app.upload();"
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
					mp3 = Mp3Info.open(tmp_file)
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
		
		###################
		##    Public     ##
		## API Functions ##
		###################
		
		get "/info/artist" do
			return { :error => true, :message => "Must provide artist." }.to_json unless params[:artist]
			@info.artist(params[:artist]).to_json
		end
		
		get "/info/album" do
		
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
		
		get "/logout" do
			# @auth.invalidate
			session.clear
			redirect '/login'
		end
	end
end