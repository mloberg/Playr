require 'data_mapper'
require 'dm-adjust'
require 'dm-aggregates'

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
	property :uploaded_by, Integer
	property :created_at, DateTime
	property :updated_at, DateTime
	
	has n, :votes
	has n, :queues
	has n, :histories
	
	def self.search(query)
		q = '%' + query + '%'
		results = repository(:default).adapter.select("SELECT * FROM `songs` WHERE `title` LIKE ? OR `artist` LIKE ? OR `album` LIKE ? OR `genre` LIKE ?", q, q, q, q)
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
	
	has n, :votes
end

class Queue
	include DataMapper::Resource
	property :added_by, Integer
	property :created_at, DateTime
	
	belongs_to :song, :key => true
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
end

class History
	include DataMapper::Resource
	property :id, Serial
	property :started_at, DateTime
	
	belongs_to :song
end

DataMapper.auto_upgrade!