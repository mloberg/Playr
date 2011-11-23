require 'sinatra'
require './database'
require './auth'
#require 'database'
#require 'rack-flash'
#require 'sinatra/redirect_with_flash'

use Rack::Session::Pool, :expire_after => 2592000
#use Rack::Flash, :sweep => true

#SITE_TITLE = ""
#SITE_DESCRIPTION = ""

set(:auth) do |val|
	condition do
		redirect '/login' unless @auth and @auth.valid?
	end
end

before do
	SESS = session
	if session[:user_id]
		@user = User.get session[:user_id]
		@auth = Auth.new(@user.password, @user.secret)
	else
		
	end
end

get "/", :auth => true do
	#UserAuth.crypt "admin"
	"authenticated!"
end

get '/info' do
	session[:user_id].to_s
end

get '/clear' do
	session[:user_id] = nil
end

get "/login" do
	if @auth and @auth.valid?
		redirect '/'
	else
		erb :login
	end
end

post "/login" do
	username = params[:username]
	user = User.first(:username => username)
	session[:user_id] = user.id
	redirect '/'
end