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
	property :title, String, :length => 512, :required => true
	property :artist, String, :length => 512, :required => true
	property :album, String, :length => 512
	property :year, Integer
	property :tracknum, Integer
	property :genre, String
	property :length, Float, :required => true
	property :votes, Float, :default => 500
	property :plays, Integer
	property :uploaded_by, Integer
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

#zoos = repository(:default).adapter.select('SELECT name, open FROM zoos WHERE name = ?', 'Awesome Zoo')

DataMapper.finalize.auto_upgrade!