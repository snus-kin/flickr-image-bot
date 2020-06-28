import httpclient, xmlparser, xmltree, random, parsecfg, streams, strtabs, json, os
import twitter

proc searchFlickr(apiKey: string, searchTags: string): XmlNode =
  # Create a httpClient and get a search for 500 images
  var client = newHttpClient()
  var body = newMultipartData()
  body["method"] = "flickr.photos.search"
  body["api_key"] = apiKey
  body["tags"] = searchTags
  body["sort"] = "date-posted-desc"
  body["per_page"] = "500"
  body["extras"] = "license,url_o"

  var resp = client.post("https://api.flickr.com/services/rest/", multipart=body)
  if resp.status != "200 OK":
    raise newException(ValueError, "POST /rest/ status " & resp.status)
  client.close()

  try:
    var parsed = parseXml(resp.body)
    return parsed
  except XmlError:
    stderr.writeline("Malformed XML Response from flickr")
    quit(1)

proc checkPhoto(attrib: XmlNode, configDir: string): bool =
  # Check a single XML node to see if it can be posted
  # Check license info
  if attrib.attr("license") notin ["7", "9", "10"]:
    return false

  # Check we haven't posted it already, against a file, open as RW to create if not existing
  var fileStream = newFileStream(configDir & "posted_ids.txt", fmRead)
  defer: fileStream.close()
  var line = ""
  while fileStream.readLine(line):
    if line == attrib.attr("id"):
      return false
  return true

proc downloadPhoto(url: string): string =
  # Download a photo given a url, returns a string
  let client = newHttpClient()
  let resp = client.getContent(url)
  client.close()
  return resp

proc makeTweet(image: string, tweetString: string, configFile: string): bool=
  # Actually tweet the thing!
  # Build stuff
  let config = loadConfig(configFile)
  let consumerToken = newConsumerToken(config.getSectionValue("API", "twitterConsumer"),
                                       config.getSectionValue("API", "twitterConsumerSecret"))
  let twitterAPI = newTwitterApi(consumerToken,
                                 config.getSectionValue("API", "twitterToken"),
                                 config.getSectionValue("API", "twitterSecret"))
  
  # Send the image to the upload server
  var ubody = newStringTable()
  ubody["media_category"] = "tweet_image"
  ubody["media"] = ""
  let uresp = twitterAPI.post("media/upload.json", ubody, media=true, data=image)
  if uresp.status != "200 OK":
    raise newException(ValueError, "POST /media/upload.json status " & uresp.status)
  
  # Extract media id from upload
  let media_id = parseJson(uresp.body)["media_id_string"].getStr()
  
  # Now, send the tweet
  var tbody = newStringTable()
  tbody["status"] = tweetString
  tbody["media_ids"] = media_id
  let tresp = twitterAPI.statusesUpdate(tbody)
  if tresp.status != "200 OK":
    raise newException(ValueError, "POST /statuses/update.json status " & uresp.status)
  
  return true

proc makeConfig(file: string): void =
  # make the config file
  let contents = [
    "[General]",
    "searchTags=\"\"\n",
    "[API]",
    "flickrApiKey=\"\"",
    "twitterConsumer=\"\"",
    "twitterConsumerSecret=\"\"",
    "twitterToken=\"\"",
    "twitterSecret=\"\""
  ]

  let cfg = open(file, fmWrite)
  defer: cfg.close()

  for line in contents:
    cfg.writeLine(line)
  
when isMainModule:
  # seed random number generator
  randomize()
  # load config file, create the folder if it doesn't exist
  const configDir = getHomeDir() & ".config/flickr_image_bot/"
  if not existsDir(configDir):
    createDir(configDir)
  
  const configFile = configDir & "twitter_bot.cfg"
  if not existsFile(configFile):
    makeConfig(configFile)
    echo("Config file created")
    quit(0)

  let config = loadConfig(configFile)
  let flickrApiKey = config.getSectionValue("API", "flickrApiKey")
  let searchTags = config.getSectionValue("General", "searchTags")
  
  # do the search
  var search_xml = searchFlickr(flickrApiKey, searchTags)
  
  # Pick a random child index to try, otherwise try the next one
  var chosen: XmlNode
  while true:
    var index = rand(0..len(search_xml.child("photos")))
    chosen = search_xml.child("photos")[index]
    if checkPhoto(chosen, configDir):
      break

  # The flickr link is in the form https://www.flickr.com/photos/{user-id}/{photo-id}
  let flickrLink = "https://flickr.com/photos/" & chosen.attr("owner") & "/" & chosen.attr("id")
  let tweetString = chosen.attr("title") & "\n\n" & flickrLink

  # download the photo saving as a binary string
  let photo = downloadPhoto(chosen.attr("url_o"))

  # tweet it
  let success = makeTweet(photo, tweetString, configFile)

  if success:
    let f = open(configDir & "posted_ids.txt", fmAppend)
    defer: f.close()
    f.write(chosen.attr("id")&"\n")
