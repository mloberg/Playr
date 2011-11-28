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
				$("album-list").set("html", "");
				$("song-list").set("html", "");
			}
			Browse.currentStep = "artist";
			Browse.info["artist"] = this.get("text");
			$("artists").removeClass("span6").addClass("span4");
			$("albums").removeClass("span4").addClass("span6");
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
			$("albums").removeClass("span6").addClass("span4");
			$("songs").removeClass("span4").addClass("span6");
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
			new Request({
				method: 'get',
				url: '/info/song/' + this.get("id"),
				onComplete: function(song){
					console.log(song);
				}
			}).send();
		});
	}

};