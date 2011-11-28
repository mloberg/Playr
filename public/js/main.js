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
	
	browse: function(){
		Browse.artist();
	}

};

Browse = {

	info: {},
	currentStep: null,
	
	artist: function(){
		$$(".artist").addEvent("click", function(){
			if(Browse.currentStep != null){
				$("album-list").getChildren().fade("out");
				$("song-list").getChildren().fade("out");
				setTimeout('$("song-list").set("html", "");', 300);
			}
			Browse.currentStep = "artist";
			Browse.info["artist"] = this.get("text");
			$("artists").morph(".span4");
			$("albums").morph(".span6");
			new Request({
				method: 'get',
				url: '/browse/' + Browse.info["artist"],
				onRequest: function(){
					$("album-list").set("html", "<li>loading...</li>");
				},
				onComplete: function(resp){
					$("album-list").set("html", resp);
					Browse.album();
				}
			}).send();
		});
	},
	
	album: function(){
		$$(".album").addEvent("click", function(){
			if(Browse.currentStep != "artist"){
				$("song-list").set("html", "");
			}
			Browse.currentStep = "album";
			Browse.info["album"] = this.get("text");
			$("albums").morph(".span4");
			$("songs").morph(".span6");
			new Request({
				method: 'get',
				url: '/browse/' + Browse.info["artist"] + '/' + Browse.info["album"],
				onRequest: function(){
					$("song-list").set("html", "<li>loading...</li>");
				},
				onComplete: function(resp){
					$("song-list").set("html", resp);
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
					var sm = new SimpleModal({draggable:false});
					sm.addButton("Action Button", "btn primary", function(){
						//Queue.add(song.id);
						this.hide();
					});
					sm.addButton("Cancel", "btn");
					sm.show({
						"model": "modal",
						"title": "Title",
						"contents": "your message..."
					});
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