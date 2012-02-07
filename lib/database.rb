app_dir = File.expand_path(File.dirname(__FILE__) + '/../')
$: << app_dir
require "yaml"
require "data_mapper"
require "dm-adjust"
require "dm-aggregates"
require "securerandom"
require "statistics2"
require "lib/auth"

CONFIG = YAML.load_file("#{app_dir}/config/config.yml")

DataMapper::setup(:default, {
	:adapter => "mysql",
	:host => CONFIG["db"]["host"],
	:username => CONFIG["db"]["user"],
	:password => CONFIG["db"]["pass"],
	:database => CONFIG["db"]["db"]
})

@first_song_uploaded = nil

def popularity(pos, n, y, x)
	if @first_song_uploaded == nil
		@first_song_uploaded = Song.first
	end
	m = Time.parse(@first_song_uploaded.created_at.to_s)
	x = Time.parse(x.to_s)
	c = (m.to_f / x.to_f)
	c = 0.99 if c >= 1.0
	pos = pos + y
	n = n + y
	return -1.0 if n == 0
	z = Statistics2.pnormaldist(1 - (1 - c) / 2)
	phat = pos.to_f / n
	(phat + z * z / (2 * n) - z * Math.sqrt((phat * (1 - phat) + z * z / (4 * n)) / n)) / (1 + z * z / n)
end

module Helper
	def to_h
		hash = {}
		self.instance_variables.each do |var|
			hash[var.to_s.delete("@")] = self.instance_variable_get(var) if not var.to_s =~ /^@_/
		end
		hash
	end
end

class Song
	include DataMapper::Resource
	include Helper
	property :id, Serial
	property :path, FilePath, :required => true
	property :title, String, :length => 512, :required => true
	property :artist, String, :length => 512, :required => true
	property :album, String, :length => 512
	property :year, Integer
	property :tracknum, Integer
	property :genre, String
	property :length, Float, :required => true
	property :score, Float, :default => -1.0
	property :plays, Integer, :default => 0
	property :created_at, DateTime
	property :updated_at, DateTime
	property :last_played, DateTime
	
	has n, :votes
	has n, :histories
	has n, :songQueues
	
	belongs_to :user, :required => false
	
	def self.artists
		all(:fields => [:artist], :unique => true, :order => [:artist.asc])
	end
	
	def self.albums(artist = nil)
		if artist == nil
			all(:fields => [:artist, :album], :unique => true, :order => [:album.asc])
		else
			all(:artist => artist, :fields => [:artist, :album], :unique => true, :order => [:album.asc])
		end
	end
	
	def self.tracks(artist, album = nil)
		if album == nil
			all(:artist => artist)
		else
			all(:artist => artist, :album => album)
		end
	end

	def self.search(term)
		like = "%#{term}%"
		results = {}
		results[:tracks] = all(:title.like => like)
		results[:albums] = all(:album.like => like, :fields => [:artist, :album], :unique => true)
		results[:artists] = all(:artist.like => like, :fields => [:artist], :unique => true)
		# results[:genre] = all(:genre.like => like, :fields => [:genre], :unique => true)
		results
	end
end

class User
	include DataMapper::Resource
	property :id, Serial
	property :username, String, :required => true, :unique => true
	property :password, String, :length => 1024, :required => true
	property :secret, String, :length => 1024, :required => true
	property :name, String
	property :email, String, :default => CONFIG["default_email"], :format => :email_address
	property :admin, Boolean, :default => false
	
	has n, :votes
	has n, :songs

	def self.add(params)
		u = new
		password = params[:password]
		u.attributes = params.merge({
			:password => Auth.hash_password(password),
			:secret => SecureRandom.hex(16)
		})
		u.save
	end
end

class SongQueue
	include DataMapper::Resource
	property :created_at, DateTime
	
	belongs_to :song, :key => true
	
	def self.add(song)
		q = get(song.id)
		if q
			return false
		else
			create(:song => song, :created_at => Time.now)
		end
	end

	def self.in_queue(sid)
		q = get(sid)
		return false unless q
		true
	end

	def self.remove(sid)
		q = get(sid)
		q.destroy
	end
end

class Vote
	include DataMapper::Resource
	property :like, Boolean, :default => false
	
	belongs_to :song, :key => true
	belongs_to :user, :key => true
	
	def self.up(song, user)
		vote = get(song.id, user.id)
		if vote and vote.like == false
			vote.update(:like => true)
		elsif vote == nil
			create(:user => user, :song => song, :like => true)
		end
		score(song)
	end
	
	def self.down(song, user)
		vote = get(song.id, user.id)
		if vote and vote.like == true
			vote.update(:like => false)
		elsif vote == nil
			create(:user => user, :song => song, :like => false)
		end
		score(song)
	end

	def self.score(song)
		likes = all(:song => song)
		positive = likes.drop_while { |i| i.like == false }
		song.update(:score => popularity(positive.size, likes.size, song.plays, song.created_at))
	end

	def self.song(song)
		all(:song => song, :like => true)
	end

	def self.likes(sid, uid)
		l = get(sid, uid)
		return nil unless l
		l.like
	end

	def self.user(user)
		all(:user => user)
	end
end

class History
	include DataMapper::Resource
	property :id, Serial
	property :played_at, DateTime
	
	belongs_to :song
end

DataMapper.finalize.auto_upgrade!