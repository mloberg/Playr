require 'bcrypt'
require 'digest/md5'

class Auth

	def self.hash_password(password)
		BCrypt::Password.create(password)
	end
	
	def initialize(pass, secret, session, server)
		@hash = pass
		@secret = secret
		@session = session
		@server = server
	end
	
	def validate(pass)
		if BCrypt::Password.new(@hash) == pass
			@session[:fingerprint] = BCrypt::Password.create(Digest::MD5.hexdigest(@server['HTTP_USER_AGENT']) + @secret)
			return true
		else
			return false
		end
	end
	
	def is_valid?
		fingerprint_value = Digest::MD5.hexdigest(@server['HTTP_USER_AGENT']) + @secret
		if BCrypt::Password.new(@session[:fingerprint]) == fingerprint_value
			return true
		else
			return false
		end
	end

end