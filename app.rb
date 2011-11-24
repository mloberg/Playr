require 'sinatra'
require './database'
require './auth'
require 'rack-flash'
require 'sinatra/redirect_with_flash'

#use Rack::Session::Pool, :expire_after => 2592000
enable :sessions
use Rack::Flash, :sweep => true

#SITE_TITLE = ""
#SITE_DESCRIPTION = ""

set(:auth) do |val|
	condition do
		redirect '/login' unless @auth and @auth.is_valid?
	end
end

before do
	$_SERVER = request.env
	$_SESSION = session
	if session[:user_id]
		@user = User.get session[:user_id]
		@auth = Auth.new(@user.password, @user.secret)
	end
end

get "/", :auth => true do
	#UserAuth.crypt "admin"
	"authenticated"
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
	@auth = Auth.new(user.password, user.secret)
	if @auth.validate(password)
		session[:user_id] = user.id
		redirect '/'
	else
		redirect '/login', :error => "Invalid username/password combination."
	end
end