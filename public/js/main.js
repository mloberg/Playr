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
		$$("li").addEvent("click", function(){
			var $this = this,
				siblings = this.getSiblings(),
				artist = new Element("p").inject(document.body);
			siblings.fade("out");
			setTimeout(function(){
				artist.set("text", $this.get("text")).setPosition($this.getPosition()).setStyle("position", "absolute");
				$this.getParent().destroy();
				artist.morph({
					top: "10px",
					left: "100px"
				});
			}, 500);
		});
	}

};