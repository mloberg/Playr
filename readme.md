# Playr

Playr is an ruby application to manage music in a community environment (like an office). Users can upload music, add music to a queue, and like and dislike tracks. It integrates with Last.fm's API to get artist, album, and track information.

## Requirements

* Mac OS X 10.5 or later
* Ruby 1.9
* bundler (gem install bundler)
* MySQL (brew install mysql)
* Redis (brew install redis)
* faad (for m4a files) (brew install faad2)
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

### Playr keeps crashing on startup

Production mode uses port 80. Any port below 1024 requires admin privileges. Either run `sudo ruby playr.rb` or change (or comment out) the port line in *lib/app.rb*.

# Growl Playr

Included is a Growl plugin for Playr that will update the currently playing song using Growl. It supports both Growl 1.3 and 1.2.x.

## Requirements

* Mac OS X 10.5 or later
* Growl 1.2.x or 1.3
* Ruby 1.8.7 or later
* Shell access

## Installation

To install growl-playr, you will need to copy the `growl` directory to the users system, cd to the directory and run `ruby installer.rb`. It will ask you a few things and move all the necessary files into place.

## Usage

Once you have run the installation, the growl plugin is available with `growl-playr`.

	growl-playr start # start growl-playr
	growl-playr stop # stop growl-playr
	growl-playr restart # restart growl-playr
	growl-playr status # check if growl-playr is running

## Important Notes

If you are using RVM on your system, you will need to make sure you are running the system default Ruby so the necessary gems are installed. To use the system's Ruby install run `rvm system`. Then after the install is done, `rvm use 1.9.3` or whatever version of Ruby you were using.
