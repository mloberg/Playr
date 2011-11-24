require 'bcrypt'
require 'digest/md5'

class Auth

	def self.hash_password(password)
		BCrypt::Password.create(password)
	end
	
	def initialize(pass, secret)
		@hash = pass
		@secret = secret
	end
	
	def validate(pass)
		if BCrypt::Password.new(@hash) == pass
			$_SESSION[:fingerprint] = BCrypt::Password.create(Digest::MD5.hexdigest($_SERVER['HTTP_USER_AGENT']) + @secret)
			return true
		else
			return false
		end
	end
	
	def is_valid?
		fingerprint_value = Digest::MD5.hexdigest($_SERVER['HTTP_USER_AGENT']) + @secret
		if BCrypt::Password.new($_SESSION[:fingerprint]) == fingerprint_value
			return true
		else
			return false
		end
	end

end