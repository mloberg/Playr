require 'bcrypt'

class Auth

	# class methods
	
	def self.logged_in?
		return false unless SESS[:user_id]
		
	end
	
	# instance methods
	
	def initialize(pass, secret)
		@pass = pass
		@secret = secret
	end
	
	def valid?
		return true if @secret
	end

end