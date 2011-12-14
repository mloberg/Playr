var Playr = {},
	Browse = {},
	Queue = {},
	Info = {},
	Templates = {};

Playr = {

	init: function(){
		$$(".dropdown-toggle").addEvent("click", function(e){
			e.preventDefault();
			this.getParent("li").toggleClass("open");
		});
		Playr.voting();
		Playr.updates();
	},
	
	upload: function(){
		var uploader = new qq.FileUploader({
			element: $("file-uploader"),
			action: "/api/song/add",
			debug: false,
			onComplete: function(id, fileName, resp){
				if(resp.error === true){
					alert(resp.message);
				}
			}
		});
	},
	
	browse: function(options){
		if(typeof options === "undefined") options = {};
		Browse.artist();
		if(options.artist !== "undefined"){
			$$('.artist:contains("' + options.artist + '")').fireEvent("click");
			if(options.album !== "undefined"){
				var browseAlbums = setInterval(function(){
					if($("album-list").get("html") != "" && $("album-list").get("html") != "<li>loading...</li>"){
						$$('.album:contains("' + options.album + '")').fireEvent("click");
						clearInterval(browseAlbums);
					}
				}, 50);
			}
		}
	},
	
	updates: function(){
		WEB_SOCKET_SWF_LOCATION = "/WebSocketMain.swf";
		var ws = new WebSocket("ws://localhost:10081/");
		ws.onmessage = function(e){
			humane.timeout = 5000;
			humane.info(e.data);
			humane.timeout = 2500;
		};
	},
	
	paginate: function(){
		var url = "/" + window.location.href.split("/").pop();
		$$(".next-page").addEvent("click", function(e){
			var that = this;
			e.preventDefault();
			new Request({
				method: "get",
				url: url,
				data: {
					page: that.get("data-page"),
					ajax: true
				},
				onComplete: function(resp){
					$$(".content").set("html", resp);
					Playr.paginate();
				}
			}).send();
		});
		$$(".prev-page").addEvent("click", function(e){
			var that = this;
			e.preventDefault();
			new Request({
				method: "get",
				url: url,
				data: {
					page: that.get("data-page"),
					ajax: true
				},
				onComplete: function(resp){
					$$(".content").set("html", resp);
					Playr.paginate();
				}
			}).send();
		});
	},
	
	controls: function(vol){
		if($("play-next") !== null){
			$("play-next").addEvent("click", function(){
				if(confirm("Are you sure?")){
					new Request({
						method: "post",
						url: "/api/next",
						onComplete: function(msg){
							$$(".now-playing").fade("out");
							setTimeout(function(){
								$$(".now-playing").destroy();
								Queue.next();
							}, 500);
						}
					}).send();
				}
			});
		}else if($("start-playr") !== null){
			$("start-playr").addEvent("click", function(){
				new Request.JSON({
					method: "post",
					url: "/api/play",
					onComplete: function(resp){
						if(resp.error){
							humane.error(resp.message);
						}else{
							humane.success(resp.message);
							Queue.next();
						}
					}
				}).send();
			});
		}
		$$(".dont-play").addEvent("click", function(){
			if(confirm("Are you sure?")){
				var sid = this.get("data-song");
				new Request({
					method: "post",
					url: "/api/skip",
					data: {
						song: sid
					},
					onComplete: function(msg){
						$("song-" + sid).fade("out");
						setTimeout(function(){
							$("song-" + sid).destroy();
						}, 500);
					}
				}).send();
			}
		});
		var mySlide = new Slider($("slider"), $("knob"), {
			initialStep: vol,
			onChange: function(pos){
				$("volume-label").set("html", pos);
			},
			onComplete: function(pos){
				new Request.JSON({
					method: "post",
					url: "/api/volume",
					data: { level: pos }
				}).send();
			}
		});
		$("mute").addEvent("click", function(e){
			e.preventDefault();
			mySlide.set(0);
		});
		$("play-pause").addEvent("click", function(e){
			e.preventDefault();
			var url = "/api/play",
				msg = "Are you sure?",
				that = this;
			if(that.get("data-playing") === "true"){
				url = "/api/pause";
				msg = msg + " This will stop the current track.";
			}
			if(confirm(msg)){
				new Request.JSON({
					method: "post",
					url: url,
					onComplete: function(resp){
						if(resp.success && that.get("data-playing") === "true"){
							that.set("data-playing", "false");
							that.set("text", "Play");
						}else if(resp.success){
							that.set("data-playing", "true");
							that.set("text", "Pause");
						}
					}
				}).send();
			}
		});
	},
	
	voting: function(){
		$$(".like").addEvent("click", function(){
			if(!this.hasClass("disabled")){
				var that = this,
					sid = this.get("data-song"),
					dislike = that.getSiblings(".dislike");
				new Request({
					method: "post",
					url: "/api/like",
					data: {
						song: sid
					},
					onComplete: function(msg){
						if(dislike.hasClass("disabled")) dislike.removeClass("disabled");
						that.addClass("disabled");
					}
				}).send();
			}
		});
		$$(".dislike").addEvent("click", function(){
			if(!this.hasClass("disabled")){
				var that = this,
					sid = this.get("data-song"),
					like = that.getSiblings(".like");
				new Request({
					method: "post",
					url: "/api/dislike",
					data: {
						song: sid
					},
					onComplete: function(msg){
						if(like.hasClass("disabled")) like.removeClass("disabled");
						that.addClass("disabled");
					}
				}).send();
			}
		});
	}

};

Browse = {

	info: {},
	currentStep: null,
	
	artist: function(){
		$$(".artist").addEvent("click", function(){
			if(Browse.currentStep !== null){
				$("artist-info").set("html", "");
				$("album-artwork").fade("out");
				$("album-list").getChildren().fade("out");
				$("song-list").getChildren().fade("out");
				setTimeout(function(){
					$("song-list").set("html", "");
					$("album-artwork").set("html", "");
				}, 300);
			}
			Browse.currentStep = "artist";
			Browse.info.artist = this.get("text");
			$("artists").morph(".span4");
			$("albums").morph(".span6");
			new Request.JSON({url: "/api/artist/info", onSuccess: function(artist){
				$("artist-info").set("html", '<img src="' + artist.image + '" alt="' + Browse.info.artist + '" />');
			}}).get({ artist: Browse.info.artist });
			new Request.JSON({
				method: "get",
				url: "/api/artist/albums",
				data: { artist: Browse.info.artist },
				onRequest: function(){
					$("album-list").set("html", "<li>loading...</li>");
				},
				onComplete: function(albums){
					$("album-list").set("html", "");
					albums.each(function(album){
						$("album-list").adopt(new Element("li", {
							"class": "album",
							text: album
						}));
					});
					Browse.album();
				}
			}).send();
		});
	},
	
	album: function(){
		$$(".album").addEvent("click", function(){
			if(Browse.currentStep !== "artist"){
				$("album-artwork").set("html", "");
				$("song-list").set("html", "");
			}
			Browse.currentStep = "album";
			Browse.info.album = this.get("text");
			$("albums").morph(".span4");
			$("songs").morph(".span6");
			new Request.JSON({url: "/api/album/artwork", onSuccess: function(artwork){
				$("album-artwork").set("html", '<img src="' + artwork + '" alt="' + Browse.info.album + '" />').fade("in");
			}}).get({ artist: Browse.info.artist, album: Browse.info.album });
			new Request.JSON({
				method: "get",
				url: "/api/album/tracks",
				data: {
					artist: Browse.info.artist,
					album: Browse.info.album
				},
				onRequest: function(){
					$("song-list").set("html", "<li>loading...</li>");
				},
				onComplete: function(songs){
					$("song-list").set("html", "");
					songs.each(function(song){
						var text = "";
						if(song.tracknum !== null) text += song.tracknum + ": ";
						text += song.title;
						$("song-list").adopt(new Element("li", {
							id: song.id,
							"class": "song",
							text: text
						}));
					});
					Browse.song();
				}
			}).send();
		});
	},
	
	song: function(){
		$$(".song").addEvent("click", function(){
			Browse.currentStep = "song";
			new Request.JSON({
				method: "get",
				url: "/api/song",
				data: { id: this.get("id") },
				onComplete: function(song){
					var sm = new SimpleModal({
						offsetTop: 100,
						draggable: false,
						width: 700
					});
					if(!song.in_queue){
						sm.addButton("Add To Queue", "btn primary", function(){
							Queue.add(song.id);
							this.hide();
						});
					}
					sm.addButton("Track Info", "btn", function(){
						window.location.href = "/track/" + song.id;
					});
					sm.show({
						model: "modal",
						title: "Add Song To Queue?",
						contents: Templates.songPopup(song)
					});
				}
			}).send();
		});
	}

};

Queue = {

	add: function(id){
		var req = new Request.JSON({
			method: "post",
			url: "/api/queue/add",
			data: { "id" : id },
			onComplete: function(resp){
				if(resp.error){
					humane.error(resp.message);
				}else{
					humane.success("Song added to queue.");
				}
			}
		}).send();
	},
	
	next: function(){
		var queue = $$(".queue")[0],
			h3 = queue.getChildren("h3")[0],
			info = queue.getElements(".span6")[0],
			btns = queue.getElements(".buttons")[0];
		$$(".paused").destroy();
		queue.removeClass("queue").removeClass("offset3").removeClass("span10").addClass("span16").addClass("now-playing");
		new Element("h2", { text: "Now Playing" }).inject(queue, "top");
		h3.inject(info, "top");
		btns.getChildren(".dont-play")[0].destroy();
		new Element("a", {
			"class": "btn",
			id: "play-next",
			text: "Next"
		}).inject(btns);
		Playr.controls();
	}

};

Info = {

	artist: function(){
		var clearfix = new Element("div", { "class": "clear"}),
			similarArtists = $$(".similar-artist"),
			lastArtist = similarArtists.length - 1,
			height = 0;
		similarArtists.each(function(brick, key){
			if((key + 1) % 3 === 0){
				clearfix.inject(brick, "after");
			}
			if(key > 2){
				var brickAbove = similarArtists[key - 3],
					brickAboveCoords = brickAbove.getCoordinates(),
					brickCoords = brick.getCoordinates(),
					bricksHeight = brickAboveCoords.height + brickCoords.height;
				brick.setStyle("position", "relative").setPosition({
					x: (brickAboveCoords.left - brickCoords.left),
					y: (brickAboveCoords.bottom - brickCoords.top)
				});
				if(height < bricksHeight){
					height = bricksHeight;
					brick.getParent().setStyle("height", bricksHeight + 50);
				}
			}
		});
	},
	
	track: function(id){
		$("delete").addEvent("click", function(e){
			e.preventDefault();
			if(confirm("Are you sure?")){
				var delete_track = new Element("form", {
					action: "/api/track",
					method: "post",
					styles: {
						display: "none"
					}
				}).inject(document.body);
				new Element("input", {
					type: "hidden",
					name: "_method",
					value: "delete"
				}).inject(delete_track);
				new Element("input", {
					type: "hidden",
					name: "song_id",
					value: id
				}).inject(delete_track);
				delete_track.submit();
			}
		});
		$("queue-up").addEvent("click", function(){
			var sm = new SimpleModal({
				offsetTop: 100,
				draggable: false,
				hideHeader: true
			});
			sm.addButton("Add To Queue", "btn primary", function(){
				Queue.add(id);
				this.hide();
			});
			sm.addButton("Cancel", "btn");
			sm.show({
				model: "modal",
				contents: "Add this song to the queue?"
			});
		});
	}

};

Templates = {

	songPopup: function(view){
		return Mustache.to_html(
			'<div class="row">' +
				'<div class="span4">' +
					'<img src="{{artwork}}" alt="{{artist}}" />' +
				'</div>' +
				'<div class="span4">' +
					'<p>' +
						'<strong>Song</strong>: {{title}}<br />' +
						'<strong>Artist</strong>: {{artist}}<br />' +
						'<strong>Album</strong>: {{album}}<br />' +
						'<strong>Plays</strong>: {{plays}}<br />' +
						'<strong>In Queue</strong>: {{in_queue}}' +
					'</p>' +
				'</div>' +
			'</div>', view);
	}

};