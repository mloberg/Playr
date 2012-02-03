app_dir = File.expand_path(File.dirname(__FILE__) + '/../')
$: << app_dir
require "yaml"
require "data_mapper"
require "dm-adjust"
require "dm-aggregates"
require "statistics2"
require "securerandom"
require "lib/auth"

config = YAML.load_file("#{app_dir}/config/config.yml")

DataMapper::setup(:default, {
	:adapter => "mysql",
	:host => config["db"]["host"],
	:username => config["db"]["user"],
	:password => config["db"]["pass"],
	:database => config["db"]["db"]
})

def popularity(pos, n, confidence = 0.95)
	if n == 0
		return 0
	end
	z = Statistics2.pnormaldist(1 - (1 - confidence) / 2)
	phat = 1.0 * pos / n
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
	property :score, Float, :default => 0.0
	property :plays, Integer, :default => 0
	property :created_at, DateTime
	property :updated_at, DateTime
	property :last_played, DateTime
	
	has n, :votes
	has n, :songQueues
	has n, :histories
	
	belongs_to :user
	
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
	property :email, String, :default => 'mail@example.com', :format => :email_address
	property :admin, Boolean, :default => false
	
	has n, :votes
	has n, :songs

	def self.add(params)
		u = new
		u.attributes = params.merge({
			:password => Auth.hash_password(params[:password]),
			:secret => SecureRandom.hex(16)
		})
		u.save
	end
end

class SongQueue
	include DataMapper::Resource
	property :added_by, Integer
	property :created_at, DateTime
	
	belongs_to :song, :key => true

	def self.in_queue(song)
		q = all(:song => song)
		return false if q.empty?
		true
	end
end

class Vote
	include DataMapper::Resource
	property :like, Boolean, :default => false
	belongs_to :song, :key => true
	belongs_to :user, :key => true
	
	def self.up(sid, uid)
		vote = get(sid, uid)
		song = Song.get(sid)
		if vote and vote.like == false
			vote.update(:like => true)
		elsif not vote
			user = User.get(uid)
			create(:user => user, :song => song, :like => true)
		end
		score(song)
	end
	
	def self.down(sid, uid)
		vote = get(sid, uid)
		song = Song.get(sid)
		if vote and vote.like == true
			vote.update(:like => false)
		elsif not vote
			user = User.get(uid)
			create(:user => user, :song => song)
		end
		score(song)
	end

	def self.score(song)
		likes = all(:song => song)
		positive = likes.drop_while { |i| i.like == false }
		song.update(:score => popularity(positive.size, likes.size))
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