(function() {
  var exports, fs, mkdirp;

  fs = require("fs");

  mkdirp = require("mkdirp").sync;

  exports = module.exports = function(options) {
    var callbackChunk, callbackCreated, callbackFinished, filesPath, generateUniqueID, getID, respond, uploadRoute, uploadRx;

    options = options || {};
    filesPath = options.files || "./uploads";
    uploadRoute = options.uploadRoute || "/upload";
    callbackCreated = options.onCreated;
    callbackChunk = options.onChunk;
    callbackFinished = options.onFinished;
    uploadRx = new RegExp(uploadRoute + "/([a-z0-9]{4,24})");
    generateUniqueID = function() {
      return (Math.floor(Math.random() * 100000000)).toString(36) + (+new Date()).toString(36);
    };
    getID = function(path) {
      var fid, match;

      match = uploadRx.exec(path);
      if (!match) {
        return false;
      }
      fid = match[1];
      if (!(fs.existsSync(filesPath + "/" + fid) && fs.existsSync(filesPath + "/" + fid + ".json"))) {
        return false;
      }
      return fid;
    };
    respond = function(res, status, head) {
      res.writeHead(status, head);
      return res.end();
    };
    if (!fs.existsSync(filesPath)) {
      mkdirp(filesPath);
    }
    return function(request, response, next) {
      var dta, fid, id, loc, meta;

      if (request.path.indexOf(uploadRoute) !== 0) {
        return next();
      }
      switch (request.method) {
        case "POST":
          if (!(request.path === uploadRoute && request.get("Final-Length"))) {
            return next();
          }
          id = generateUniqueID();
          fs.createWriteStream(filesPath + "/" + id).end();
          dta = JSON.stringify({
            finalLength: request.get("Final-Length"),
            fileName: ""
          });
          fs.createWriteStream(filesPath + "/" + id + ".json", {
            encoding: "UTF-8"
          }).end(dta);
          loc = "http://" + request.get("host") + uploadRoute + "/" + id;
          respond(response, 201, {
            "Location": loc
          });
          if (typeof callbackCreated === "function") {
            return callbackCreated(id);
          }
          break;
        case "HEAD":
          fid = getID(request.path);
          if (!fid) {
            return next();
          }
          return fs.stat(filesPath + "/" + fid, function(err, stats) {
            if (!err) {
              return respond(response, 200, {
                "Offset": stats.size
              });
            } else {
              return next();
            }
          });
        case "PATCH":
          fid = getID(request.path);
          if (!fid) {
            return next();
          }
          meta = JSON.parse(fs.readFileSync(filesPath + "/" + fid + ".json", {
            encoding: "UTF-8"
          }));
          return fs.stat(filesPath + "/" + fid, function(err, stats) {
            var curOffset, offset;

            if (!err) {
              curOffset = stats.size;
              offset = request.get("Offset");
              request.pipe(fs.createWriteStream(filesPath + "/" + fid, {
                flags: "r+",
                start: parseInt(offset, 10)
              }));
              return respond(response, 200);
            } else {
              return next();
            }
          });
        default:
          return next();
      }
    };
  };

}).call(this);
