Playr = {

	init: function(){
		
	},
	
	upload: function(){
		var uploader = new qq.FileUploader({
			element: document.getElementById("file-uploader"),
			action: '/add',
			debug: false,
			onComplete: function(id, fileName, resp){
				if(resp.error == true){
					alert(resp.message);
				}
			}
		});
	},
	
	browse: function(options){
		if(typeof options == "undefined") options = {};
		Browse.artist();
		if(options.artist != ""){
			$$('.artist:contains("' + options.artist + '")').fireEvent('click');
			if(options.album != ""){
				var browseAlbums = setInterval(function(){
					if($("album-list").get("html") != "" && $("album-list").get("html") != "<li>loading...</li>"){
						$$('.album:contains("' + options.album + '")').fireEvent('click');
						clearInterval(browseAlbums);
					}
				}, 50);
			}
		}
	}

};

Browse = {

	info: {},
	currentStep: null,
	
	artist: function(){
		$$(".artist").addEvent("click", function(){
			if(Browse.currentStep != null){
				$("artist-info").set("html", "");
				$("album-artwork").fade("out");
				$("album-list").getChildren().fade("out");
				$("song-list").getChildren().fade("out");
				setTimeout('$("song-list").set("html", "");$("album-artwork").set("html", "");', 300);
			}
			Browse.currentStep = "artist";
			Browse.info["artist"] = this.get("text");
			$("artists").morph(".span4");
			$("albums").morph(".span6");
			new Request.JSON({url: '/api/artist/info', onSuccess: function(artist){
				$("artist-info").set("html", '<img src="' + artist.image + '" alt="' + Browse.info["artist"] + '" />');
			}}).get({ artist: Browse.info["artist"] });
			new Request.JSON({
				method: 'get',
				url: '/api/artist/albums',
				data: { artist: Browse.info["artist"] },
				onRequest: function(){
					$("album-list").set("html", "<li>loading...</li>");
				},
				onComplete: function(albums){
					$("album-list").set("html", "");
					albums.each(function(album){
						$("album-list").adopt(new Element('li', {
							class: 'album',
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
			if(Browse.currentStep != "artist"){
				$("album-artwork").set("html", "");
				$("song-list").set("html", "");
			}
			Browse.currentStep = "album";
			Browse.info["album"] = this.get("text");
			$("albums").morph(".span4");
			$("songs").morph(".span6");
			new Request.JSON({url: '/api/album/artwork', onSuccess: function(artwork){
				$("album-artwork").set("html", '<img src="' + artwork + '" alt="' + Browse.info["album"] + '" />').fade("in");
			}}).get({ artist: Browse.info["artist"], album: Browse.info["album"] });
			new Request.JSON({
				method: 'get',
				url: '/api/album/tracks',
				data: {
					artist: Browse.info["artist"],
					album: Browse.info["album"]
				},
				onRequest: function(){
					$("song-list").set("html", "<li>loading...</li>");
				},
				onComplete: function(songs){
					$("song-list").set("html", "");
					songs.each(function(song){
						$("song-list").adopt(new Element('li', {
							class: 'song',
							text: song.title
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
				method: 'get',
				url: '/info/song/' + this.get("id"),
				onComplete: function(song){
					var sm = new SimpleModal({
						offsetTop: 100,
						draggable:false,
						width: 700
					});
					if(song.in_queue){
						alert("song is in queue!");
					}else{
						sm.addButton("Add To Queue", "btn primary", function(){
							//Queue.add(song.id);
							this.hide();
						});
						sm.addButton("Cancel", "btn");
						sm.show({
							model: "modal",
							title: "Add Song To Queue?",
							contents: "<p>Song: " + song.title + "</p><p>Artist: " + song.artist + "</p><p>Album: " + song.album + "</p>"
						});
					}
				}
			}).send();
		});
	}

};

Queue = {

	add: function(id){
		var req = new Request({
			method: 'post',
			url: '/queue/add',
			data: { 'id' : id },
			onComplete: function(){
				
			}
		}).send();
	}

};