require './app/app'

APP_DIR = File.expand_path(File.dirname(__FILE__) + '/../')

use Rack::ShowExceptions

run Playr::App