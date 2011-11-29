require 'sinatra'
require './database'
require './auth'
require 'rack-flash'
require 'sinatra/redirect_with_flash'
require 'active_support/secure_random'
require 'sinatra/redis'
require 'fileutils'
require 'json'
require 'mp3info'

#use Rack::Session::Pool, :expire_after => 2592000
enable :sessions
use Rack::Flash, :sweep => true

SITE_TITLE = "Playr"

def in_queue(id)
	queue = Queue.get(id)
	return true if queue
	return false
end

set(:auth) do |val|
	condition do
		redirect '/login' unless @auth and @auth.is_valid?
		redirect '/' if val == :admin and session[:user_id] != 1
	end
end

before do
	if session[:user_id]
		@user = User.get session[:user_id]
		@auth = Auth.new(@user.password, @user.secret, session, request.env)
	end
end

get "/", :auth => true do
	@title = "Home"
	erb :index
end

get "/queue", :auth => true do
	@title = "Queue"
	queue = Queue.all(:order => [ :created_at.asc ])
	@songs = []
	queue.each do |q|
		s = Song.get(q.song_id)
		@songs << s
	end
	@songs
	erb :queue
end

post "/queue/add", :auth => true do
	if not in_queue params[:id]
		q = Queue.new
		q.attributes = {
			:song_id => params[:id],
			:added_by => @user.id,
			:created_at => Time.now
		}
		q.save
	end
end

get "/queue/search/:id", :auth => true do
	return in_queue(params[:id]).to_json
end

get "/browse", :auth => true do
	@title = 'Browse'
	@artists = redis.smembers "artists"
	@artists.sort!
	@script = '<script src="/js/simple-modal.js"></script>'
	@ready = 'Playr.browse();'
	erb :browse
end

get "/browse/:artist", :auth => true do
	@albums = redis.smembers params[:artist].gsub(" ", "") + ":albums"
	@albums.sort!
	erb :artist, :layout => :none
end

get "/browse/:artist/:album", :auth => true do
	@songs = Song.all(:artist => params[:artist], :album => params[:album], :order => [ :tracknum.asc ])
	erb :album, :layout => :none
end

get "/info/song/:id", :auth => true do
	@song = Song.get(params[:id])
	@song["in_queue"] = in_queue params[:id]
	@song.to_json
end

get "/add", :auth => true do
	@title = "Upload Songs"
	@script = '<script src="/js/fileuploader.js"></script>'
	@ready = 'Playr.upload();'
	erb :upload
end

post "/add", :auth => true do
	# upload file to tmp folder
	directory = './tmp/'
	if params[:qqfile].class == String
		name = params[:qqfile]
		string_io = request.body
		data_bytes = string_io.read
		path = File.join(directory, name)
		File.open(path, "w") do |f|
			f.write(data_bytes)
		end
	else
		name = params[:qqfile][:filename]
		path = File.join(directory, name)
		File.open(path, "wb") do |f|
			f.write(params[:qqfile][:tempfile].read)
		end
	end
	# parse song for information
	tmp_file = directory + name
	mp3 = Mp3Info.open(tmp_file)
	if not mp3.tag.title
		FileUtils.rm(tmp_file)
		return {:error => true, :message => "No ID3 tags found!"}.to_json
	end
	# see if duplicate song exists
	if Song.first(:title => mp3.tag.title, :artist => mp3.tag.artist, :album => mp3.tag.album, :length => mp3.length)
		FileUtils.rm(tmp_file)
		return {:error => true, :message => "Song already exists."}.to_json
	end
	# move file
	ext = File.extname(tmp_file)
	file_name = mp3.tag.title + ext
	target_path = './music/' + mp3.tag.artist + '/' + mp3.tag.album + '/'
	FileUtils.mkdir_p target_path unless File.exists? target_path
	FileUtils.mv(tmp_file, target_path + file_name)
	# add to Redis and MySQL
	s = Song.new
	s.attributes = {
		:title => mp3.tag.title,
		:artist => mp3.tag.artist,
		:album => mp3.tag.album,
		:year => mp3.tag.year,
		:tracknum => mp3.tag.tracknum,
		:genre => mp3.tag.genre_s,
		:length => mp3.length,
		:uploaded_by => @user.id,
		:created_at => Time.now,
		:updated_at => Time.now
	}
	s.save
	redis.sadd "artists", mp3.tag.artist
	redis.sadd mp3.tag.artist.gsub(" ", "") + ":albums", mp3.tag.album
	
	# must return for file uploader to mark as success
	return {:success => true}.to_json
end

get "/user/add", :auth => :admin do
	erb :add_user
end

post "/user/add", :auth => :admin do
	if User.first(:username => params[:username])
		redirect '/user/add', :error => "Username is already taken."
	else
		u = User.new
		u.attributes = {
			:username => params[:username],
			:password => Auth.hash_password(params[:password]),
			:secret => ActiveSupport::SecureRandom.hex(16),
			:name => params[:name]
		}
		if u.save
			redirect '/', :notice => "User #{params[:username]} added"
		else
			redirect '/user/add', :error => "Could not add user"
		end
	end
end

# Login/Logout
get "/logout" do
	session[:user_id] = nil
	session[:fingerprint] = nil
	redirect '/login'
end

get "/login" do
	@title = "Login"
	if @auth and @auth.is_valid?
		redirect '/'
	else
		erb :login
	end
end

post "/login" do
	username = params[:username]
	password = params[:password]
	user = User.first(:username => username)
	@auth = Auth.new(user.password, user.secret, session, request.env)
	if @auth.validate(password)
		session[:user_id] = user.id
		redirect '/'
	else
		redirect '/login', :error => "Invalid username/password combination."
	end
end