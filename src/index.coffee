# Require built-in libs
fs = require "fs"

# 3rd party libs
mkdirp = require("mkdirp").sync


exports = module.exports = (options) ->

  # Options
  options = options || {}
  filesPath = options.files || "./uploads"
  uploadRoute = options.uploadRoute || "/upload"
  callbackCreated = options.onCreated
  callbackChunk = options.onChunk
  callbackFinished = options.onFinished

  # Regex to return requested file ID
  uploadRx = new RegExp(uploadRoute + "/([a-z0-9]{4,24})")


  ## Functions
  generateUniqueID = () ->
    (Math.floor(Math.random()*100000000)).toString(36) + (+new Date()).toString(36)

  getID = (path) ->
    match = uploadRx.exec path
    return false unless match
    fid = match[1]
    return false unless fs.existsSync(filesPath + "/" +fid) && fs.existsSync(filesPath + "/" + fid + ".json")
    return fid

  respond = (res, status, head) ->
    res.writeHead status, head
    res.end()

  # Create paths, if necessary.
  if !fs.existsSync filesPath
    mkdirp filesPath

  # Request handler
  return (request, response, next) ->

    # Is the request TUS-related?
    return next() unless request.path.indexOf(uploadRoute) == 0

    switch request.method

      # File creation
      when "POST"
        # Make sure the request is well formatted.
        return next() unless request.path == uploadRoute && request.get "Final-Length"

        # Generate a unique resource ID and create the empty file
        id = generateUniqueID()
        fs.createWriteStream( filesPath+"/"+id ).end()

        # Create the upload metadata JSON file
        dta = JSON.stringify
          finalLength: request.get "Final-Length"
          fileName: ""
        fs.createWriteStream( filesPath+"/"+id+".json", encoding: "UTF-8" ).end( dta )

        # Gemerate location and write response.
        loc = "http://" + request.get("host") + uploadRoute + "/" + id
        respond response, 201, "Location": loc

        if typeof callbackCreated == "function"
          callbackCreated id

      # Getting file info
      when "HEAD"
        # Check if a valid file ID was passed, otherwise next...
        fid = getID request.path
        return next() unless fid

        # Check file length
        fs.stat filesPath + "/" +fid, (err, stats) ->
          if !err
            # Write response
            respond response, 200, "Offset": stats.size
          else
            return next()

      # Appending data to a file.
      when "PATCH"
        # Check if a valid file ID was passed, otherwise next...
        fid = getID request.path
        return next() unless fid
        meta = JSON.parse(fs.readFileSync(filesPath + "/" + fid + ".json", encoding: "UTF-8"))
        fs.stat filesPath + "/" +fid, (err, stats) ->
          if !err
            curOffset = stats.size
            offset = request.get "Offset"
            request.pipe( fs.createWriteStream( filesPath + "/" +fid, flags:"r+", start: parseInt(offset,10) ) )
            respond response, 200
          else
            return next()

      else return next()
