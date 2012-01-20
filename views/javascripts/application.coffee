class @Playr
	constructor: ->
		this.voting()
		$$(".dropdown-toggle").addEvent "click", (e) ->
			e.preventDefault()
			this.getParent("li").toggleClass "open"
	upload: ->
		uploader = new qq.FileUploader({
			element: $("file-uploader"),
			action: "/upload",
			debug: false,
			onComplete: (id, fileName, resp) ->
				if resp.error is true
					alert resp.message
		})
	voting: ->
		$$(".like").addEvent "click", ->
			if !this.hasClass "disabled"
				that = this
				sid = that.get "data-song"
				dislike = that.getSiblings ".dislike"
				request = new Request {
					method: "post",
					url: "/api/like",
					data: { song: sid },
					onComplete: (msg) ->
						if dislike.hasClass "disabled"
							dislike.removeClass "disabled"
						that.addClass "disabled"
				}
				request.send()
		$$(".dislike").addEvent "click", ->
			if !this.hasClass "disabled"
				that = this
				sid = that.get "data-song"
				like = that.getSiblings ".like"
				request = new Request {
					method: "post",
					url: "/api/dislike",
					data: { song: sid },
					onComplete: (msg) ->
						if like.hasClass "disabled"
							like.removeClass "disabled"
						that.addClass "disabled"
				}
	paginate: ->
		self = this
		url = window.location.pathname
		$$(".next-page").addEvent "click", (e) ->
			that = this
			e.preventDefault()
			request = new Request {
				method: "get",
				url: url,
				data: {
					page: that.get("data-page"),
					ajax: true
				},
				onRequest: ->
					$("content").set "html", "<h3 class=\"center\">Loading...</h3>"
				onComplete: (resp) ->
					$("content").set "html", resp
					self.paginate()
			}
			request.send()
		$$(".prev-page").addEvent "click", (e) ->
			that = this
			e.preventDefault()
			request = new Request {
				method: "get",
				url: url,
				data: {
					page: that.get("data-page"),
					ajax: true
				},
				onRequest: ->
					$("content").set "html", "<h3 class=\"center\">Loading...</h3>"
				onComplete: (resp) ->
					$("content").set "html", resp
					self.paginate()
			}
			request.send()

class @Browse
	info: {}
	currentStep: null
	constructor: (options) ->
		this.artist()
		if typeof options is "undefined"
			options = {}
		unless typeof options.artist is "undefined"
			$$(".artist:contains(#{options.artist.replace('"', '\"')})").fireEvent "click"
			unless options.album is "undefined"
				browseAlbums = setInterval ->
					html = $("album-list").get "html"
					if html isnt "" and html isnt "<li>loading...</li>"
						$$(".album:contains(#{options.album.replace('"', '\"')})").fireEvent "click"
						clearInterval browseAlbums
				, 50
	artist: ->
		self = this
		$$(".artist").addEvent "click", ->
			unless self.currentStep is null
				$("artist-info").set "html", ""
				$("album-artwork").fade "out"
				$("album-list").getChildren().fade "out"
				$("song-list").getChildren().fade "out"
				setTimeout ->
					$("song-list").set "html", ""
					$("album-artwork").set "html", ""
				, 300
			self.currentStep = "artist"
			self.info.artist = this.get "text"
			$("artists").morph ".span4"
			$("albums").morph ".span6"
			requestArtwork = new Request.JSON {
				url: "/api/info",
				onSuccess: (artist) ->
					artwork = null
					Object.each artist.image, (image) ->
						if image['#text'].match(/\d{3}.?\/\d+\.(png|jpg)$/) and artwork is null
							artwork = image['#text']
					$("artist-info").set "html", "<img src=\"#{artwork}\" alt=\"#{self.info.artist}\" />"
			}
			request = new Request.JSON {
				method: "get",
				url: "/api/get",
				data: {
					method: "albums",
					artist: self.info.artist
				},
				onRequest: ->
					$("album-list").set "html", "<li>loading...</li>"
				onComplete: (albums) ->
					$("album-list").set "html", ""
					Object.each albums, (album)->
						$("album-list").adopt(new Element "li", {
							class: "album",
							text: album.album
						})
					self.album();
			}
			requestArtwork.get { method: "artist", artist: self.info.artist }
			request.send()
	album: ->
		self = this
		$$(".album").addEvent "click", ->
			unless self.currentStep is "artist"
				$("album-artwork").set "html", ""
				$("song-list").set "html", ""
			self.currentStep = "album"
			self.info.album = this.get "text"
			$("albums").morph ".span4"
			$("songs").morph ".span6"
			requestArtwork = new Request.JSON {
				url: "/api/info",
				onSuccess: (album) ->
					artwork = null
					Object.each album.image, (image) ->
						if image['#text'].match(/\d{3}.?\/\d+\.(png|jpg)$/) and artwork is null
							artwork = image['#text']
					if artwork is null
						artwork = 'http://placehold.it/174&text=No+Artwork+Found'
					$("album-artwork").set "html", "<img src=\"#{artwork}\" alt=\"#{self.info.album}\" />"
			}
			request = new Request.JSON {
				method: "get",
				url: "/api/get",
				data: {
					method: "tracks",
					artist: self.info.artist,
					album: self.info.album
				},
				onRequest: ->
					$("song-list").set "html", "<li>loading...</li>"
				onComplete: (songs) ->
					$("song-list").set "html", ""
					Object.each songs, (song) ->
						text = song.title
						unless song.tracknum is null
							text = song.tracknum + ": " + text
						$("song-list").adopt(new Element "li", {
							id: song.id,
							html: "<a class=\"song\" href=\"/track/#{song.id}\">#{text}</a>"
						})
					self.song()
			}
			requestArtwork.get { method: "album", artist: self.info.artist, album: self.info.album }
			request.send()
	song: ->
		self = this
		$$(".song").addEvent "click", (e) ->
			self.currentStep = "song"
			if confirm "Add this song to the queue?"
				e.preventDefault()
				# add song to queue
