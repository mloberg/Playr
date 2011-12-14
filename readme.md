# Playr

Playr is an ruby application to manage music in a community environment (like an office). Users can upload music and music to a queue.

## Requirements

* Mac OS X 10.5 or greater
* Ruby 1.9 (developed with 1.9.3)
* bundler (gem install bundler)
* MySQL (brew install mysql)
* Redis (brew install redis)
* Last.fm API account (http://last.fm/api)

## Installation

How to get Playr up and running.

### Download

Download Playr and cd into it's directory.

### Gems

To install all the necessary gems, simply run `bundle install`

### MySQL

Playr will need it's own database, so create one for it and make sure the database information matches it in *lib/database.rb*

### Config

By default Playr is set to run in production mode. The main difference between production and development or testing is production runs on port 80 and all css and js assets are compressed into one file (done on app run) and are cached for a week. If you wish to change either the mode to run in, or the cache time, open up *lib/app.rb* and change those settings. If you add any css or js files, you will need to add them to the SCRIPTS and STYLES variables (respectively).

## Running

Running Playr is simple.

	ruby playr.rb

If it's your first time running it, it will set up your Last.fm API information and then start the Sinatra app, otherwise it will just start the Sinatra app.