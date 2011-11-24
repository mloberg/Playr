require 'sinatra'
require './database'
require './auth'
require 'rack-flash'
require 'sinatra/redirect_with_flash'
require 'active_support/secure_random'

#use Rack::Session::Pool, :expire_after => 2592000
enable :sessions
use Rack::Flash, :sweep => true

#SITE_TITLE = ""
#SITE_DESCRIPTION = ""

set(:auth) do |val|
	condition do
		redirect '/login' unless @auth and @auth.is_valid?
		if val == :admin and session[:user_id] != 1
			redirect '/'
		end
	end
end

before do
	if session[:user_id]
		@user = User.get session[:user_id]
		@auth = Auth.new(@user.password, @user.secret, session, request.env)
	end
end

get "/", :auth => true do
	#UserAuth.crypt "admin"
	"authenticated"
end

get "/user/add", :auth => :admin do
	erb :add_user
end

post "/user/add", :auth => :admin do
	if User.first(:username => params[:username])
		redirect '/user/add', :error => "Username is already taken."
	else
		u = User.new
		u.attributes = {
			:username => params[:username],
			:password => Auth.hash_password(params[:password]),
			:secret => ActiveSupport::SecureRandom.hex(16),
			:name => params[:name]
		}
		if u.save
			redirect '/', :notice => "User #{params[:username]} added"
		else
			redirect '/user/add', :error => "Could not add user"
		end
	end
end

# Login/Logout
get "/logout" do
	session[:user_id] = nil
	session[:fingerprint] = nil
	redirect '/login'
end

get "/login" do
	if @auth and @auth.is_valid?
		redirect '/'
	else
		erb :login
	end
end

post "/login" do
	username = params[:username]
	password = params[:password]
	user = User.first(:username => username)
	@auth = Auth.new(user.password, user.secret, session, request.env)
	if @auth.validate(password)
		session[:user_id] = user.id
		redirect '/'
	else
		redirect '/login', :error => "Invalid username/password combination."
	end
end