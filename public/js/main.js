var Playr = new Class({

	initialize: function(){
		$$(".dropdown-toggle").addEvent("click", function(e){
			e.preventDefault();
			this.getParent("li").toggleClass("open");
		});
	},
	
	upload: function(){
		var uploader = new qq.FileUploader({
			element: $("file-uploader"),
			action: "/upload",
			debug: false,
			onComplete: function(id, fileName, resp){
				if(resp.error === true){
					alert(resp.message);
				}
			}
		});
	}

});