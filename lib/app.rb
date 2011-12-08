require 'lib/auth'
require 'lib/lastfm'
require 'lastfm_api_key'

enable :sessions
use Rack::Flash, :sweep => true

SITE_TITLE = "Playr"

helpers do
	def album_artwork(album, artist)
		return redis.hget "album:artwork", album + ":" + artist if redis.hexists "album:artwork", album + ":" + artist
		artwork = @lastfm.album_artwork album, artist
		redis.hset "album:artwork", album + ":" + artist, artwork
		artwork
	end
	
	def artist_info(artist)
		return redis.hget "artist:info", artist if redis.hexists "artist:info", artist
		info = @lastfm.artist artist
#		info["image"].each{ |i| info["image"] = i["#text"] if i["size"] == "large" }
		redis.hset "artist:info", artist, info.to_json
		info.to_json
	end
	
	def like(song)
		Vote.up(song, @user.id)
	end
	
	def dislike(song)
		Vote.down(song, @user.id)
	end
	
	def likes(song)
		Vote.count(:song => song, :like => true)
	end
	
	def cache(key, value = nil)
		c = redis.hget "cache", key
		unless c
			redis.hset "cache", key, value.to_json
			c = value.to_json
		end
		JSON.parse(c)
	end
	
	def get_cache(key)
		c = redis.hget "cache", key
		return JSON.parse(c) if c
	end
	
	def set_cache(key, value)
		redis.hset "cache", key, value.to_json
	end
	
	def hashify(obj)
		hash = {}
		obj.instance_variables.each do |var|
			hash[var.to_s.delete("@")] = obj.instance_variable_get(var) if not var.to_s =~ /^@_/
		end
		hash
	end
	
	def likes?(sid)
		like = Vote.get(sid, @user.id)
		return nil unless like
		return like.like
	end
	
	def avatar(email, size = 80)
		hash = Digest::MD5.hexdigest(email.downcase)
		img_src = "http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=mm"
	end
	
	def in_queue(song)
		q = Queue.all(:song => song)
		return false if q.empty?
		return true
	end
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
	@lastfm = LastFM.new(LASTFM_API_KEY, LASTFM_SECRET)
	@lastfm.session = LASTFM_SESSION
end

############
## ROUTES ##
############

get "/", :auth => true do
	@title = "Home"
	erb :index
end

############
## Browse ##
############

get "/browse", :auth => true do
	@title = 'Browse'
	@artists = Song.all(:fields => [:artist], :unique => true, :order => [:artist.asc])
	@ready = 'Playr.browse();'
	erb :browse
end

get "/browse/:artist", :auth => true do
	@title = 'Browse'
	@artists = Song.all(:fields => [:artist], :unique => true, :order => [:artist.asc])
	@ready = "Playr.browse({ artist: '#{params[:artist]}' });"
	erb :browse
end

get "/browse/:artist/:album", :auth => true do
	@title = 'Browse'
	@artists = Song.all(:fields => [:artist], :unique => true, :order => [:artist.asc])
	@ready = "Playr.browse({ artist: '#{params[:artist]}', album: '#{params[:album]}' });"
	erb :browse
end

###########
## Queue ##
###########

get "/queue", :auth => true do
	@title = "Queue"
	@playing = History.last.song
	@queue = Queue.all(:order => [ :created_at.asc ])
	erb :queue
end

########################
## Artist/Album/Track ##
########################

get "/track/:track", :auth => true do
	if params[:track].to_i != 0
		@song = Song.get(params[:track])
		halt 404, "track not found!" unless @song
		@title = @song.title
		@info = @lastfm.track(@song.title, @song.artist)
		if @info["album"]
			@info["album"]["image"].each { |i| @image = i["#text"] if i["size"] == "extralarge" }
		end
		@likes = Vote.all(:song => @song)
		@ready = "Info.track(#{@song.id.to_s});"
		erb :'info/track'
	else
		@song = Song.all(:title => params[:track])
		if @song.size == 0
			halt 404, "no tracks found!"
		elsif @song.size == 1
			@song = @song.pop
			@title = @song.title
			@info = @lastfm.track(@song.title, @song.artist)
			if @info["album"]["image"]
				@info["album"]["image"].each { |i| @image = i["#text"] if i["size"] == "extralarge" }
			end
			@likes = Vote.all(:song => @song)
			@ready = "Info.track(#{@song.id.to_s});"
			erb :'info/track'
		else
			@title = 'Multiple Tracks'
			erb :'info/multi_tracks'
		end
	end
end

get "/album/:album/?:artist?", :auth => true do
	unless params[:artist]
		@artist = repository(:default).adapter.select("SELECT DISTINCT(`artist`) FROM `songs` WHERE album=?", params[:album])
		if @artist.count == 0
			halt 404, "no album found!"
		elsif @artist.count != 1
			@title = 'Multiple Albums'
			return erb :'info/multi_albums'
		end
		@artist = @artist.pop
	else
		@artist = params[:artist]
	end
	@title = params[:album]
	@album = get_cache(@artist + ':' + @title)
	unless @album
		@album = @lastfm.album(@title, @artist)
		set_cache(@artist + ':' + @title, @album)
	end
	@album["image"].each { |i| @image = i["#text"] if i["size"] == "extralarge" }
	songs = Song.all(:album => @title, :artist => @artist, :order => [:tracknum.asc])
	@tracks = {}
	if @album["tracks"]["track"].kind_of? Array
		album_tracks = @album["tracks"]["track"]
	else
		album_tracks = @album["tracks"]
	end
	puts album_tracks
	unless album_tracks.kind_of? String
		album_tracks.each do |t|
			t = t.pop if t.kind_of? Array
			@tracks[t["@attr"]["rank"].to_i] = {
				:available => false,
				:name => t["name"]
			}
		end
	end
	songs.each do |t|
		@tracks[t.tracknum] = {
			:available => true,
			:id => t.id,
			:name => t.title
		}
	end
	erb :'info/album'
end

get "/artist/:artist", :auth => true do
	@title = params[:artist]
	@ready = 'Info.artist();'
	@artist = JSON.parse(artist_info params[:artist])
	@artist["image"].each { |i| @image = i["#text"] if i["size"] == "mega" }
	@albums = repository(:default).adapter.select("SELECT DISTINCT(`album`) FROM `songs` WHERE artist=?", params[:artist])
	erb :'info/artist'
end

get "/artists", :auth => true do
	@title = "Artists"
	artists = Song.all(:fields => [:artist], :unique => true, :order => [:artist.asc])
	@artists = {}
	artists.each do |artist|
		artist_info = JSON.parse(artist_info(artist.artist))
		image = ''
		artist_info["image"].each { |i| image = i["#text"] if i["size"] == "extralarge" }
		@artists[artist.artist] = image
	end
	erb :artists
end

get "/albums", :auth => true do
	@title = "Albums"
	@albums = Song.all(:fields => [:artist, :album], :unique => true, :order => [:album.asc])
	erb :albums
end

get "/track/:id/edit", :auth => true do
	@title = "Edit Track"
	@song = Song.get(params[:id])
	erb :'edit/track'
end

############
## Search ##
############

get "/search", :auth => true do
	@title = "Search"
	@results = Song.search(params[:q])
	erb :search
end

#################
## Upload Song ##
#################

get "/upload", :auth => true do
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
	artists = Song.all(:fields => [:artist], :unique => true, :order => [:artist.asc])
	return artists.to_json
end

get "/api/list/albums" do
	albums = Song.all(:fields => [:artist, :album], :unique => true, :order => [:album.asc])
	return albums.to_json
end

# ?artist=:artist
get "/api/artist/info" do
	return { :error => true, :message => "Must provide artist." }.to_json unless params[:artist]
	artist = JSON.parse(artist_info params[:artist])
	artist["image"].each { |i| artist["image"] = i["#text"] if i["size"] == "large"}
	return artist.to_json
end

# ?artist=:artist
get "/api/artist/albums" do
	return { :error => true, :message => "Must provide artist." }.to_json unless params[:artist]
	albums = repository(:default).adapter.select("SELECT DISTINCT(`album`) FROM `songs` WHERE artist=?", params[:artist])
	return albums.to_json
end

# return album artwork
# ?artist=:artist&album=:album
get "/api/album/artwork" do
	return { :error => true, :message => "Must provide artist and album," }.to_json unless params[:artist] and params[:album]
	artwork = album_artwork params[:album], params[:artist]
	return artwork.to_json
end

# ?artist=:artist&album=:album
get "/api/album/tracks" do
	return { :error => true, :message => "Must provide artist and album." }.to_json unless params[:artist] and params[:album]
	songs = Song.all(:artist => params[:artist], :album => params[:album], :order => [ :tracknum.asc ])
	return songs.to_json
end

# ?id=:id or ?artist=:artist&album=:album&song=:song_title
get "/api/song" do
	if params[:id]
		song = Song.get(params[:id]).to_h
		song["in_queue"] = in_queue params[:id]
		song["artwork"] = album_artwork(song["album"], song["artist"])
		return song.to_json
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
	ext = File.extname(name)[1..-1].downcase
	tags = {}
	case ext
		when 'mp3'
			mp3 = Mp3Info.open(tmp_file)
			unless mp3.tag.title
				FileUtils.rm(tmp_file)
				return { :error => true, :message => "No tags found. Please add some tags and try again." }.to_json
			end
			tags = {
				:length => mp3.length,
				:title => mp3.tag.title,
				:artist => mp3.tag.artist,
				:album => mp3.tag.album,
				:year => mp3.tag.year,
				:tracknum => mp3.tag.tracknum,
				:genre => mp3.tag.genre || mp3.tag.genre_s
			}
		when 'aac', 'mp4', 'm4a'
			aac = AACInfo.open(tmp_file)
			unless aac.title
				FileUtils.rm(tmp_file)
				return { :error => true, :message => "No tags found. Please add some tags and try again." }.to_json
			end
			tags = {
				:length => aac.length,
				:title => aac.title,
				:artist => aac.artist,
				:album => aac.album,
				:year => aac.year,
				:tracknum => aac.track,
				:genre => aac.genre
			}
		else
			FileUtils.rm(tmp_file)
			return {:error => true, :message => "Not a supported filetype. Supported filetypes are mp3, m4a, aac, mp4." }.to_json
	end
	return { :error => true, :message => "Ran into unexpected error." }.to_json if tags.empty?
	# see if duplicate song exists
	if Song.first(:title => tags[:title], :artist => tags[:artist], :album => tags[:album], :length => tags[:length])
		FileUtils.rm(tmp_file)
		return { :error => true, :message => "Song already exists." }.to_json
	end
	# move file
	file_name = tags[:title] + "." + ext
	target_path = './music/' + tags[:artist] + '/' + tags[:album] + '/'
	FileUtils.mkdir_p target_path unless File.exists? target_path
	FileUtils.mv(tmp_file, target_path + file_name)
	# add to MySQL
	s = Song.new
	s.attributes = {
		:path => target_path + file_name,
		:uploaded_by => @user.id,
		:created_at => Time.now,
		:updated_at => Time.now
	}.merge(tags)
	s.save
	
	# must return for file uploader to mark as success
	return { :success => true }.to_json
end

post "/api/queue/add", :auth => true do
	return { :error => true, :message => "Requires song id." }.to_json unless params[:id]
	return { :error => true, :message => "This song is already in the queue." }.to_json if in_queue params[:id]
	s = Song.get(params[:id])
	q = Queue.new
	q.attributes = {
		:song => s,
		:added_by => @user.id,
		:created_at => Time.now
	}
	return { :success => true, :message => "Song added to end of the queue." }.to_json if q.save
	return { :error => true, :message => "Could not add song to queue." }.to_json
end

put "/api/track", :auth => true do
	song = Song.get(params[:song_id])
	song.update(:title => params[:title], :artist => params[:artist], :album => params[:album], :tracknum => params[:tracknum], :year => params[:year], :genre => params[:genre], :updated_at => Time.now)
	redirect "/track/#{params[:song_id]}", :notice => "Track info updated."
end

delete "/api/track", :auth => true do
	song = Song.get(params[:song_id])
	if song.destroy
		`rm -f #{song.path}`
		redirect '/', :notice => 'Song deleted.'
	else
		redirect "/track/#{params[:song_id]}", :error => 'Could not delete song.'
	end
end

post "/api/like", :auth => true do
	like(params[:song])
	return { :success => true, :message => 'Liked song'}.to_json
end

post "/api/dislike", :auth => true do
	dislike(params[:song])
	return { :success => true, :message => 'Disliked song' }.to_json
end

get "/api/playing", :auth => true do
	playing = History.last
	if Time.parse(playing.started_at).to_i + playing.song.length > Time.now.to_i
		return { :currently_playing => true, :track => playing.song }.to_json
	else
		return { :currently_playing => false, :track => nil }.to_json
	end
end

post "/api/pause", :auth => true do

end

post "/api/next", :auth => true do
	Playr.skip
	return { :success => true }.to_json
end

# remove a song from the queue
post "/api/skip", :auth => true do
	# params[:song]
	q = Queue.first(:song => Song.get(params[:song]))
	return { :success => true }.to_json if q.destroy
	return { :error => true, :message => "Could not remove track from queue." }.to_json
end

post "/api/volume", :auth => true do
	Playr.volume = params[:level]
	return { :success => true, :message => "Volume set to #{params[:level]}." }.to_json
end

get "/api/volume", :auth => true do
	return { :volume => Playr.volume }.to_json
end

####################
## User Functions ##
####################

get "/likes/?:username?", :auth => true do
	@user = User.first(:username => params[:username]) if params[:username]
	@title = "#{@user.name} Likes"
	@likes = Vote.all(:user => @user)
	erb :likes
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

##################
## Login/Logout ##
##################

get "/logout" do
	@auth.invalidate
	session[:user_id] = nil
	redirect '/login'
end

get "/login" do
	redirect '/' if @auth and @auth.is_valid?
	@title = "Login"
	erb :login
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