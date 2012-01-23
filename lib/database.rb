require 'data_mapper'
require 'dm-adjust'
require 'dm-aggregates'
require './lib/auth'

DataMapper::setup(:default, {
	:adapter => 'mysql',
	:host => 'localhost',
	:username => 'root',
	:password => 'root',
	:database => 'playr'
})

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
	property :vote, Integer, :default => 500
	property :plays, Integer, :default => 0
	property :created_at, DateTime
	property :updated_at, DateTime
	
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
end

class User
	include DataMapper::Resource
	property :id, Serial
	property :username, String, :required => true, :unique => true
	property :password, String, :length => 1024, :required => true
	property :secret, String, :length => 1024, :required => true
	property :name, String
	property :email, String, :default => 'admin@dkyinc.com', :format => :email_address
	property :admin, Boolean, :default => false
	
	has n, :votes
	has n, :songs

	def self.add(params)
		u = new
		u.attributes = {
			:username => params[:username],
			:password => Auth.hash_password(params[:password]),
			:secret => SecureRandom.hex(16),
			:name => params[:name],
			:email => params[:email]
		}
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
		if vote and vote.like == false
			Song.get(sid).adjust!(:vote => 20)
			vote.update(:like => true)
		elsif not vote
			song = Song.get(sid)
			user = User.get(uid)
			song.adjust!(:vote => 20)
			create(:user => user, :song => song, :like => true)
		end
	end
	
	def self.down(sid, uid)
		vote = get(sid, uid)
		if vote and vote.like == true
			Song.get(sid).adjust!(:vote => -20)
			vote.update(:like => false)
		elsif not vote
			song = Song.get(sid)
			user = User.get(uid)
			song.adjust!(:vote => -20)
			create(:user => user, :song => song)
		end
	end

	def self.song(song)
		all(:song => song, :like => true)
	end

	def self.likes(sid, uid)
		l = get(sid, uid)
		return nil unless l
		l.like
	end
end

class History
	include DataMapper::Resource
	property :id, Serial
	property :played_at, DateTime
	
	belongs_to :song
end

DataMapper.finalize.auto_upgrade!