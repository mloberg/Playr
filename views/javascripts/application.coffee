onImagesLoad = (callback) ->
	images = 0
	$$("img").each (item, key) ->
		images++
		img = new Image()
		img.onload = ->
			images--
		img.src = item.get "src"
	check = setInterval ->
		if images == 0
			callback()
			clearInterval check
	, 50
getParameterByName = (name) ->
	name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]")
	regexS = "[\\?&]#{name}=([^&#]*)"
	regex = new RegExp regexS
	results = regex.exec window.location.href
	if results isnt null
		return decodeURIComponent(results[1].replace(/\+/g, " "))
	null
addToQueue = (id) ->
	request = new Request.JSON {
		method: "post",
		url: "/queue",
		data: {
			id: id,
			_method: "put"
		},
		onComplete: (resp) ->
			if resp.error
				humane.error resp.message
			else
				humane.success "Song added to queue"
	}
	request.send()
	
class @Playr
	constructor: (options) ->
		this.voting()
		this.controls(options.volume)
		this.socket()
		$$(".dropdown-toggle").addEvent "click", (e) ->
			e.preventDefault()
			this.getParent("li").toggleClass "open"
	socket: ->
		self = this
		`WEB_SOCKET_SWF_LOCATION = "/WebSocketMain.swf"`
		ws = new WebSocket "ws://#{window.location.hostname}:10081/"
		ws.onmessage = (e) ->
			humane.timeout = 5000
			humane.info e.data
			humane.timeout = 2500
			if $("now-playing") isnt null
				update = setInterval ->
					$("now-playing").load("/now_playing")
					if $("now-playing").get("html") is ""
						clearInterval update
						self.voting()
						self.controls()
						queued = $$(".song-box")[0]
						queued.fade "out"
						setTimeout ->
							queued.destroy()
						, 500
				, 500
	upload: ->
		uploader = new qq.FileUploader {
			element: $("file-uploader"),
			action: "/upload",
			debug: false,
			onComplete: (id, fileName, resp) ->
				if resp.error is true
					alert resp.message
		}
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
	controls: (volume) ->
		if $("slider") and volume
			this.volume volume
		$$(".queue-up").addEvent "click", (e) ->
			e.preventDefault()
			addToQueue this.get "id"
			this.addClass "disabled"
		$$(".play-next").addEvent "click", (e) ->
			e.preventDefault()
			if confirm "Are you sure?"
				request = new Request {
					method: "post",
					url: "/api/next",
					onComplete: (msg) ->
						$$(".now-playing").fade "out"
						setTimeout ->
							$$(".now-playing").destroy()
						, 500
				}
				request.send()
		$$(".start-stop").addEvent "click", (e) ->
			e.preventDefault()
			that = this
			if confirm "Are you sure?"
				request = new Request.JSON {
					method: "post",
					url: "/api/start-stop",
					onComplete: (resp) ->
						if resp.success and that.get "text" is "Stop"
							that.set "text", "Play"
						else if resp.success
							that.set "text", "Stop"
				}
				request.send()
	volume: (volume) ->
		requestRunning = false
		volumeSlider = new Slider $("slider"), $("knob"), {
			initialStep: volume,
			onChange: (pos) ->
				if pos != volume and requestRunning is false
					requestRunning = true
					req = new Request.JSON {
						method: "post",
						url: "/api/volume",
						data: { level: pos },
						onComplete: ->
							requestRunning = false
					}
					req.send()
				volume = pos
				$("volume-label").set "html", pos
			onComplete: (pos) ->
				requestRunning = true
				request = new Request.JSON {
					method: "post",
					url: "/api/volume",
					data: { level: pos },
					onComplete: ->
						requestRunning = false
				}
				request.send()
		}
		$("mute").addEvent "click", (e) ->
			e.preventDefault()
			volumeSlider.set(0)
	queue: ->
		$$(".start-queue").addEvent "click", (e) ->
			that = this
			request = new Request.JSON {
				method: "post",
				url: "/api/start-stop",
				onComplete: (resp) ->
					if resp.success
						that.set "text", "Stop"
			}
			request.send()
		$$(".skip").addEvent "click", (e) ->
			e.preventDefault()
			sid = this.get "data-song"
			if confirm "Are you sure?"
				request = new Request {
					method: "post",
					url: "/api/skip",
					data: {
						id: sid
					},
					onComplete: ->
						$("song-#{sid}").fade "out"
						setTimeout ->
							$("song-#{sid}").destroy()
						, 500
				}
				request.send()
	history: ->
		self = this
		window.history.pushState { "html": $("content").get("html"), "pageTitle": document.title, "first": true }, "", window.location.pathname
		callback = ->
			self.paginate callback
		callback()
	artists: ->
		self = this
		window.history.pushState { "html": $("content").get("html"), "pageTitle": document.title, "first": true }, "", window.location.pathname
		callback = ->
			self._grid "artists", 5
			self.paginate callback
		callback()
	albums: ->
		self = this
		window.history.pushState { "html": $("content").get("html"), "pageTitle": document.title, "first": true }, "", window.location.pathname
		callback = ->
			self._grid "albums", 4
			self.paginate callback
		callback()
	artist: ->
		self = this
		self._grid "similar", 3
		self._grid "albums", 2
	track: (id) ->
		self = this
		$("delete").addEvent "click", (e) ->
			e.preventDefault()
			if confirm "Are you sure?"
				delete_form = new Element "form", {
					action: "/track/#{id}",
					method: "post",
					styles: { display: "none" }
				}
				method = new Element "input", {
					type: "hidden",
					name: "_method",
					value: "delete"
				}
				song_id = new Element "input", {
					type: "hidden",
					name: "song_id",
					value: id
				}
				method.inject delete_form
				song_id.inject delete_form
				delete_form.inject document.body
				delete_form.submit()
			$("queue_up").addEvent "click", (e) ->
				e.preventDefault()
				if confirm "Add this song to the queue?"
					self.addToQueue id
	paginate: (callback) ->
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
					window.history.pushState { "html": resp, "pageTitle": document.title }, "", url + "?page=" + that.get("data-page")
					callback()
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
					window.history.pushState { "html": resp, "pageTitle": document.title }, "", url + "?page=" + that.get("data-page")
					callback()
			}
			request.send()
		# watch for back forward
		window.onpopstate = (e) ->
			if e.state
				$("content").set "html", e.state.html
				callback()
				if e.state.first is true
					window.history.back()
	_grid: (grid, width) ->
		items = []
		bottom = 0
		# should trigger once all images are loaded
		onImagesLoad ->
			$(grid).getChildren("li").each (item, key) ->
				if items[key - width]
					top = items[key - width]
					item.setPosition({ x: top.x - 20, y: top.y + top.height + 20 }).setStyle "position", "absolute"
				position = item.getElement("a").getCoordinates()
				items[key] = {
					x: position.left,
					y: position.top,
					width: position.width,
					height: position.height
				}
				if bottom < position.bottom
					bottom = position.bottom
					item.getParents(".grid")[0].setStyle "height", position.bottom - items[0].y + 20

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
							html: "<a id=\"#{song.id}\" class=\"song\" href=\"/track/#{song.id}\">#{text}</a>"
						})
					self.song()
			}
			requestArtwork.get { method: "album", artist: self.info.artist, album: self.info.album }
			request.send()
	song: ->
		self = this
		$$(".song").addEvent "click", (e) ->
			self.currentStep = "song"
			that = this
			if confirm "Add this song to the queue?"
				e.preventDefault()
				addToQueue that.get "id"