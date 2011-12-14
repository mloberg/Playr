# Playr

Playr is an ruby application to manage music in a community environment (like an office). Users can upload music and add music to a queue.

## Requirements

* Mac OS X 10.5 or later
* Ruby 1.9
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

## Setup

To setup Playr run `ruby playr.rb`. This will ask your for your Last.fm api information and authorize Playr to scrobble tracks. It will then setup an admin user.

## Running

Running Playr is simple `ruby playr.rb`

## FAQ

### How do I add another user?

The admin user (the one your originally setup) is the only user that can add other users. Navigate to */user/add* and fill out the form.

### What music types are supported?

mp3 and mp4 (m4a, aac, mp4)