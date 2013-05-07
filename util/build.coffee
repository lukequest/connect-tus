# Build project

# Initialize
require("coffee-script")
process.chdir(__dirname)

# Require built-in libs
fs = require "fs"
path = require "path"

# 3rd party libs
coffee = require("coffee-script").compile
uglify = require("uglify-js").minify


# Get target path
targetPath = (filepath) ->
  relpath = path.relative("../src", path.dirname(filepath))
  fileext = path.extname(filepath)
  basename = path.basename(filepath, fileext)
  path.join("../lib", relpath, basename + if fileext==".coffee" then ".js" else fileext)


# Method for compiling and minifying coffee-script files.
compile = (srcfile) ->
  if path.extname(srcfile) == ".coffee"
    #fs.writeFileSync(targetPath(srcfile), uglify(coffee(fs.readFileSync(srcfile, "UTF-8")), (fromString: true)).code)
    fs.writeFileSync(targetPath(srcfile), coffee(fs.readFileSync(srcfile, "UTF-8")), (fromString: true))


# Build project
compile("../src/index.coffee")