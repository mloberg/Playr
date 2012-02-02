require "./app/app"
require "sass/plugin/rack"
require "barista"

APP_DIR = File.expand_path(File.dirname(__FILE__))

Sass::Plugin.options[:template_location] = 'public/scss'
Sass::Plugin.options[:stylesheet_location] = 'public/stylesheets'

Barista.root = "public/coffeescript"
Barista.output_root = "public/javascripts"

use Rack::ShowExceptions
use Rack::Session::Cookie
use Sass::Plugin::Rack
use Barista::Filter
use Barista::Server::Proxy

run Playr::App