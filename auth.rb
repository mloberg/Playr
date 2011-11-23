require 'bcrypt'
require 'digest/md5'

class Auth

	def initialize(pass, hased, secret)
		@pass = pass
		@secret = secret
	end
	
	def validate
		fingerprint = BCrypt::Engine.hash_secret(Digest::MD5.hexdigest($_SERVER['HTTP_USER_AGENT']) + @secret, BCrypt::Engine.generate_salt)
		$_SESSION[:fingerprint] = fingerprint
	end
	
	def is_valid?
		calculated_fingerprint = BCrypt::Engine.hash_secret(Digest::MD5.hexdigest($_SERVER['HTTP_USER_AGENT']) + @secret, BCrypt::Engine.generate_salt)
		if $_SESSION[:fingerprint] == calculated_fingerprint
			return true
		else
			return false
		end
	end

end