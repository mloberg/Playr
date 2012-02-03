/* DO NOT MODIFY. This file was compiled Fri, 03 Feb 2012 13:59:30 GMT from
 * /Users/mloberg/Code/ruby/Playr-dev/public/coffeescript/application.coffee
 */

(function() {
  var addToQueue, getParameterByName, onImagesLoad;

  onImagesLoad = function(callback) {
    var check, images;
    images = 0;
    $$("img").each(function(item, key) {
      var img;
      images++;
      img = new Image();
      img.onload = function() {
        return images--;
      };
      return img.src = item.get("src");
    });
    return check = setInterval(function() {
      if (images === 0) {
        callback();
        return clearInterval(check);
      }
    }, 50);
  };

  getParameterByName = function(name) {
    var regex, regexS, results;
    name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
    regexS = "[\\?&]" + name + "=([^&#]*)";
    regex = new RegExp(regexS);
    results = regex.exec(window.location.href);
    if (results !== null) {
      return decodeURIComponent(results[1].replace(/\+/g, " "));
    }
    return null;
  };

  addToQueue = function(id) {
    var request;
    request = new Request.JSON({
      method: "post",
      url: "/queue",
      data: {
        id: id,
        _method: "put"
      },
      onComplete: function(resp) {
        if (resp.error) {
          return humane.error(resp.message);
        } else {
          return humane.success("Song added to queue");
        }
      }
    });
    return request.send();
  };

  Element.implement({
    fadeAndDestroy: function(duration) {
      var el;
      duration = duration || 500;
      el = this;
      return this.set("tween", {
        duration: duration
      }).fade("out").get("tween").chain(function() {
        return el.dispose();
      });
    }
  });

  this.Playr = (function() {

    function Playr(options) {
      this.voting();
      this.controls(options.volume);
      this.socket();
      $$(".dropdown-toggle").addEvent("click", function(e) {
        e.preventDefault();
        return this.getParent("li").toggleClass("open");
      });
    }

    Playr.prototype.socket = function() {
      var self, ws;
      self = this;
      WEB_SOCKET_SWF_LOCATION = "/WebSocketMain.swf";
      ws = new WebSocket("ws://" + window.location.hostname + ":10081/");
      return ws.onmessage = function(e) {
        var request;
        humane.timeout = 5000;
        humane.info(e.data);
        humane.timeout = 2500;
        if ($("now-playing") !== null) {
          request = new Request.HTML({
            method: "get",
            url: "/api/now-playing",
            update: $("now-playing"),
            onSuccess: function(tree, elems, html, js) {
              var queued;
              self.voting();
              self.controls();
              queued = $$(".song-box")[0];
              if (queued) return queued.fadeAndDestroy();
            }
          });
          return request.send();
        }
      };
    };

    Playr.prototype.upload = function() {
      var uploader;
      return uploader = new qq.FileUploader({
        element: $("file-uploader"),
        action: "/upload",
        debug: false,
        onComplete: function(id, fileName, resp) {
          if (resp.error === true) return alert(resp.message);
        }
      });
    };

    Playr.prototype.voting = function() {
      $$(".like").removeEvents().addEvent("click", function() {
        var dislike, request, sid, that;
        if (!this.hasClass("disabled")) {
          that = this;
          sid = that.get("data-song");
          dislike = that.getSiblings(".dislike");
          request = new Request({
            method: "post",
            url: "/api/like",
            data: {
              song: sid
            },
            onComplete: function(msg) {
              if (dislike.hasClass("disabled")) dislike.removeClass("disabled");
              return that.addClass("disabled");
            }
          });
          return request.send();
        }
      });
      return $$(".dislike").removeEvents().addEvent("click", function() {
        var like, request, sid, that;
        if (!this.hasClass("disabled")) {
          that = this;
          sid = that.get("data-song");
          like = that.getSiblings(".like");
          return request = new Request({
            method: "post",
            url: "/api/dislike",
            data: {
              song: sid
            },
            onComplete: function(msg) {
              if (like.hasClass("disabled")) like.removeClass("disabled");
              return that.addClass("disabled");
            }
          });
        }
      });
    };

    Playr.prototype.controls = function(volume) {
      if ($("slider") && volume) this.volume(volume);
      $$(".start-stop").removeEvents().addEvent("click", function(e) {
        var request, that;
        e.preventDefault();
        that = this;
        if (confirm("Are you sure?")) {
          request = new Request.JSON({
            method: "post",
            url: "/api/start-stop",
            onComplete: function(resp) {
              if (resp.success && that.get("text" === "Stop")) {
                return that.set("text", "Play");
              } else if (resp.success) {
                return that.set("text", "Stop");
              }
            }
          });
          return request.send();
        }
      });
      $$(".queue-up").removeEvents().addEvent("click", function(e) {
        e.preventDefault();
        addToQueue(this.get("id"));
        return this.addClass("disabled");
      });
      return $$(".play-next").removeEvents().addEvent("click", function(e) {
        var request;
        e.preventDefault();
        if (confirm("Are you sure?")) {
          request = new Request({
            method: "post",
            url: "/api/next",
            onComplete: function(msg) {
              return $$(".now-playing").fadeAndDestroy();
            }
          });
          return request.send();
        }
      });
    };

    Playr.prototype.volume = function(volume) {
      var requestRunning, volumeSlider;
      requestRunning = false;
      volumeSlider = new Slider($("slider"), $("knob"), {
        initialStep: volume,
        onChange: function(pos) {
          var req;
          if (pos !== volume && requestRunning === false) {
            requestRunning = true;
            req = new Request.JSON({
              method: "post",
              url: "/api/volume",
              data: {
                level: pos
              },
              onComplete: function() {
                return requestRunning = false;
              }
            });
            req.send();
          }
          volume = pos;
          return $("volume-label").set("html", pos);
        },
        onComplete: function(pos) {
          var request;
          requestRunning = true;
          request = new Request.JSON({
            method: "post",
            url: "/api/volume",
            data: {
              level: pos
            },
            onComplete: function() {
              return requestRunning = false;
            }
          });
          return request.send();
        }
      });
      return $("mute").addEvent("click", function(e) {
        e.preventDefault();
        return volumeSlider.set(0);
      });
    };

    Playr.prototype.queue = function() {
      $$(".start-queue").addEvent("click", function(e) {
        var request, that;
        that = this;
        request = new Request.JSON({
          method: "post",
          url: "/api/start-stop",
          onComplete: function(resp) {
            if (resp.success) return $$(".start-stop").set("text", "Stop");
          }
        });
        return request.send();
      });
      return $$(".skip").addEvent("click", function(e) {
        var request, sid;
        e.preventDefault();
        sid = this.get("data-song");
        if (confirm("Are you sure?")) {
          request = new Request({
            method: "post",
            url: "/api/skip",
            data: {
              id: sid
            },
            onComplete: function() {
              return $("song-" + sid).fadeAndDestroy();
            }
          });
          return request.send();
        }
      });
    };

    Playr.prototype.history = function() {
      var callback, self;
      self = this;
      window.history.pushState({
        "html": $("content").get("html"),
        "pageTitle": document.title,
        "first": true
      }, "", window.location.pathname);
      callback = function() {
        return self.paginate(callback);
      };
      return callback();
    };

    Playr.prototype.artists = function() {
      var callback, self;
      self = this;
      window.history.pushState({
        "html": $("content").get("html"),
        "pageTitle": document.title,
        "first": true
      }, "", window.location.pathname);
      callback = function() {
        self._grid("artists", 5);
        return self.paginate(callback);
      };
      return callback();
    };

    Playr.prototype.albums = function() {
      var callback, self;
      self = this;
      window.history.pushState({
        "html": $("content").get("html"),
        "pageTitle": document.title,
        "first": true
      }, "", window.location.pathname);
      callback = function() {
        self._grid("albums", 4);
        return self.paginate(callback);
      };
      return callback();
    };

    Playr.prototype.artist = function() {
      var self;
      self = this;
      self._grid("similar", 3);
      return self._grid("albums", 2);
    };

    Playr.prototype.track = function(id) {
      var self;
      self = this;
      return $("delete").addEvent("click", function(e) {
        var delete_form, method, song_id;
        e.preventDefault();
        if (confirm("Are you sure?")) {
          delete_form = new Element("form", {
            action: "/track/" + id,
            method: "post",
            styles: {
              display: "none"
            }
          });
          method = new Element("input", {
            type: "hidden",
            name: "_method",
            value: "delete"
          });
          song_id = new Element("input", {
            type: "hidden",
            name: "song_id",
            value: id
          });
          method.inject(delete_form);
          song_id.inject(delete_form);
          delete_form.inject(document.body);
          delete_form.submit();
        }
        return $("queue_up").addEvent("click", function(e) {
          e.preventDefault();
          if (confirm("Add this song to the queue?")) return self.addToQueue(id);
        });
      });
    };

    Playr.prototype.search = function() {
      this._grid("albums", 2);
      return this._grid("artists", 3);
    };

    Playr.prototype.likes = function() {
      return this._grid("likes", 4);
    };

    Playr.prototype.paginate = function(callback) {
      var self, url;
      self = this;
      url = window.location.pathname;
      $$(".next-page").addEvent("click", function(e) {
        var request, that;
        that = this;
        e.preventDefault();
        request = new Request({
          method: "get",
          url: url,
          data: {
            page: that.get("data-page"),
            ajax: true
          },
          onRequest: function() {
            return $("content").set("html", "<h3 class=\"center\">Loading...</h3>");
          },
          onComplete: function(resp) {
            $("content").set("html", resp);
            window.history.pushState({
              "html": resp,
              "pageTitle": document.title
            }, "", url + "?page=" + that.get("data-page"));
            return callback();
          }
        });
        return request.send();
      });
      $$(".prev-page").addEvent("click", function(e) {
        var request, that;
        that = this;
        e.preventDefault();
        request = new Request({
          method: "get",
          url: url,
          data: {
            page: that.get("data-page"),
            ajax: true
          },
          onRequest: function() {
            return $("content").set("html", "<h3 class=\"center\">Loading...</h3>");
          },
          onComplete: function(resp) {
            $("content").set("html", resp);
            window.history.pushState({
              "html": resp,
              "pageTitle": document.title
            }, "", url + "?page=" + that.get("data-page"));
            return callback();
          }
        });
        return request.send();
      });
      return window.onpopstate = function(e) {
        if (e.state) {
          $("content").set("html", e.state.html);
          callback();
          if (e.state.first === true) return window.history.back();
        }
      };
    };

    Playr.prototype._grid = function(grid, width) {
      var bottom, items;
      items = [];
      bottom = 0;
      return onImagesLoad(function() {
        return $(grid).getChildren("li").each(function(item, key) {
          var position, top;
          if (items[key - width]) {
            top = items[key - width];
            item.setPosition({
              x: top.x - 20,
              y: top.y + top.height + 20
            }).setStyle("position", "absolute");
          }
          position = item.getElement("a").getCoordinates();
          items[key] = {
            x: position.left,
            y: position.top,
            width: position.width,
            height: position.height
          };
          if (bottom < position.bottom) {
            bottom = position.bottom;
            return item.getParents(".grid")[0].setStyle("height", position.bottom - items[0].y + 20);
          }
        });
      });
    };

    return Playr;

  })();

  this.Browse = (function() {

    Browse.prototype.info = {};

    Browse.prototype.currentStep = null;

    function Browse(options) {
      var browseAlbums;
      this.artist();
      if (typeof options === "undefined") options = {};
      if (typeof options.artist !== "undefined") {
        $$(".artist:contains(" + (options.artist.replace('"', '\"')) + ")").fireEvent("click");
        if (options.album !== "undefined") {
          browseAlbums = setInterval(function() {
            var html;
            html = $("album-list").get("html");
            if (html !== "" && html !== "<li>loading...</li>") {
              $$(".album:contains(" + (options.album.replace('"', '\"')) + ")").fireEvent("click");
              return clearInterval(browseAlbums);
            }
          }, 50);
        }
      }
    }

    Browse.prototype.artist = function() {
      var self;
      self = this;
      return $$(".artist").addEvent("click", function() {
        var request, requestArtwork;
        if (self.currentStep !== null) {
          $("artist-info").set("html", "");
          $("album-artwork").fade("out");
          $("album-list").getChildren().fade("out");
          $("song-list").getChildren().fade("out");
          setTimeout(function() {
            $("song-list").set("html", "");
            return $("album-artwork").set("html", "");
          }, 300);
        }
        self.currentStep = "artist";
        self.info.artist = this.get("text");
        $("artists").morph(".span4");
        $("albums").morph(".span6");
        requestArtwork = new Request.JSON({
          url: "/api/info",
          onSuccess: function(artist) {
            var artwork;
            artwork = null;
            Object.each(artist.image, function(image) {
              if (image['#text'].match(/\d{3}.?\/\d+\.(png|jpg)$/) && artwork === null) {
                return artwork = image['#text'];
              }
            });
            return $("artist-info").set("html", "<img src=\"" + artwork + "\" alt=\"" + self.info.artist + "\" />");
          }
        });
        request = new Request.JSON({
          method: "get",
          url: "/api/get",
          data: {
            method: "albums",
            artist: self.info.artist
          },
          onRequest: function() {
            return $("album-list").set("html", "<li>loading...</li>");
          },
          onComplete: function(albums) {
            $("album-list").set("html", "");
            Object.each(albums, function(album) {
              return $("album-list").adopt(new Element("li", {
                "class": "album",
                text: album.album
              }));
            });
            return self.album();
          }
        });
        requestArtwork.get({
          method: "artist",
          artist: self.info.artist
        });
        return request.send();
      });
    };

    Browse.prototype.album = function() {
      var self;
      self = this;
      return $$(".album").addEvent("click", function() {
        var request, requestArtwork;
        if (self.currentStep !== "artist") {
          $("album-artwork").set("html", "");
          $("song-list").set("html", "");
        }
        self.currentStep = "album";
        self.info.album = this.get("text");
        $("albums").morph(".span4");
        $("songs").morph(".span6");
        requestArtwork = new Request.JSON({
          url: "/api/info",
          onSuccess: function(album) {
            var artwork;
            artwork = null;
            Object.each(album.image, function(image) {
              if (image['#text'].match(/\d{3}.?\/\d+\.(png|jpg)$/) && artwork === null) {
                return artwork = image['#text'];
              }
            });
            if (artwork === null) {
              artwork = 'http://placehold.it/174&text=No+Artwork+Found';
            }
            return $("album-artwork").set("html", "<img src=\"" + artwork + "\" alt=\"" + self.info.album + "\" />");
          }
        });
        request = new Request.JSON({
          method: "get",
          url: "/api/get",
          data: {
            method: "tracks",
            artist: self.info.artist,
            album: self.info.album
          },
          onRequest: function() {
            return $("song-list").set("html", "<li>loading...</li>");
          },
          onComplete: function(songs) {
            $("song-list").set("html", "");
            Object.each(songs, function(song) {
              var text;
              text = song.title;
              if (song.tracknum !== null) text = song.tracknum + ": " + text;
              return $("song-list").adopt(new Element("li", {
                html: "<a id=\"" + song.id + "\" class=\"song\" href=\"/track/" + song.id + "\">" + text + "</a>"
              }));
            });
            return self.song();
          }
        });
        requestArtwork.get({
          method: "album",
          artist: self.info.artist,
          album: self.info.album
        });
        return request.send();
      });
    };

    Browse.prototype.song = function() {
      var self;
      self = this;
      return $$(".song").addEvent("click", function(e) {
        var that;
        self.currentStep = "song";
        that = this;
        if (confirm("Add this song to the queue?")) {
          e.preventDefault();
          return addToQueue(that.get("id"));
        }
      });
    };

    return Browse;

  })();

}).call(this);
