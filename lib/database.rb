require 'data_mapper'
require 'dm-adjust'

DataMapper::setup(:default, {
	:adapter => 'mysql',
	:host => 'localhost',
	:username => 'root',
	:password => 'root',
	:database => 'playr'
})

class Song
	include DataMapper::Resource
	property :id, Serial
	property :title, String, :length => 512, :required => true
	property :artist, String, :length => 512, :required => true
	property :album, String, :length => 512
	property :year, Integer
	property :tracknum, Integer
	property :genre, String
	property :length, Float, :required => true
	property :votes, Integer, :default => 500
	property :plays, Integer
	property :uploaded_by, Integer
	property :created_at, DateTime
	property :updated_at, DateTime
	
	has n, :votes
	has n, :queues
end

class User
	include DataMapper::Resource
	property :id, Serial
	property :username, String, :required => true, :unique => true
	property :password, String, :length => 1024, :required => true
	property :secret, String, :length => 1024, :required => true
	property :name, String
	
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
			Song.get(sid).adjust!(:votes => 20)
			vote.update(:like => true)
		elsif not vote
			song = Song.get(sid)
			user = User.get(uid)
			song.adjust!(:votes => 20)
			create(:user => user, :song => song, :like => true)
		end
	end
	
	def self.down(sid, uid)
		vote = get(sid, uid)
		if vote and vote.like == true
			Song.get(sid).adjust!(:votes => -20)
			vote.update(:like => false)
		elsif not vote
			song = Song.get(sid)
			user = User.get(uid)
			song.adjust!(:votes => -20)
			create(:user => user, :song => song)
		end
	end
end

DataMapper.finalize.auto_upgrade!