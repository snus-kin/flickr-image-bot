# Package

version       = "0.1.0"
author        = "snus-kin"
url           = "https://github.com/snus-kin/flickr-image-bot"
description   = "Twitter bot for fetching flickr images with tags"
license       = "GPL-3.0"
srcDir        = "src"
web           = "https://github.com/snus-kin/flickr-image-bot"
bin           = @["flickr_image_bot"]


# Dependencies

requires "nim >= 0.19.2"
requires "https://github.com/snus-kin/twitter.nim"
