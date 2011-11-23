require 'data_mapper'

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
	property :title, String, :required => true
	property :artist, String, :required => true
	property :album, String
	property :year, Integer
	property :tracknum, Integer
	property :length, Float, :required => true
	property :votes, Float, :default => 500
	property :created_at, DateTime
	property :updated_at, DateTime
end

class User
	include DataMapper::Resource
	property :id, Serial
	property :username, String, :required => true, :unique => true
	property :password, String, :length => 1024, :required => true
	property :secret, String, :length => 1024, :required => true
	property :name, String
end

DataMapper.finalize.auto_upgrade!