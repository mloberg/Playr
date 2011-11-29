require 'lib/database'
require 'lib/auth'

enable :sessions
use Rack::Flash, :sweep => true

SITE_TITLE = "Playr"

helpers do
	
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

############
## Browse ##
############

get "/browse", :auth => true do
	@title = 'Browse'
	@artists = redis.smembers "artists"
	@artists.sort!
	@script = '<script src="/js/simple-modal.js"></script>'
	@ready = 'Playr.browse();'
	erb :browse
end

get "/browse/:artist", :auth => true do
	@title = 'Browse'
	@artists = redis.smembers "artists"
	@artists.sort!
	@script = '<script src="/js/simple-modal.js"></script>'
	@ready = "Playr.browse({ artist: '#{params[:artist]}' });"
	erb :browse
end

get "/browse/:artist/:album", :auth => true do
	@title = 'Browse'
	@artists = redis.smembers "artists"
	@artists.sort!
	@script = '<script src="/js/simple-modal.js"></script>'
	@ready = "Playr.browse({ artist: '#{params[:artist]}', album: '#{params[:album]}' });"
	erb :browse
end

###########
## Queue ##
###########

get "/queue", :auth => true do
	Playr.start_queue
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

get "/info/song/:id", :auth => true do
	
end

get "/add/song", :auth => true do
	@title = "Upload Songs"
	@script = '<script src="/js/fileuploader.js"></script>'
	@ready = 'Playr.upload();'
	erb :upload
end

###################
##    Public     ##
## API Functions ##
###################

get "/api/list/artists" do
	
end

get "/api/list/albums" do
	
end

# ?artist=:artist
get "/api/artist/info" do
	
end

# ?artist=:artist
get "/api/artist/albums" do
	@albums = redis.smembers params[:artist].gsub(" ", "") + ":albums"
	@albums.sort!
	return @albums.to_json
end

# ?artist=:artist&album=:album
get "/api/album/info" do
	
end

# ?artist=:artist&album=:album
get "/api/album/tracks" do
	@songs = Song.all(:artist => params[:artist], :album => params[:album], :order => [ :tracknum.asc ])
	return @songs.to_json
end

# ?id=:id or ?artist=:artist&album=:album&song=:song_title
get "/api/song/info" do
	if params[:id]
		@song = Song.get(params[:id])
		@song["in_queue"] = in_queue params[:id]
		return @song.to_json
	end
end

###################
##   Priavate    ##
## API Functions ##
###################

post "/api/song/add", :auth => true do
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

####################
## User Functions ##
####################

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

##################
## Login/Logout ##
##################

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