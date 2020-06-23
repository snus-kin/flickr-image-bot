import httpclient, xmlparser, xmltree, random, parsecfg, streams

proc searchFlickr(apiKey: string, searchTags: string): XmlNode =
  # Create a httpClient and get a search for 500 images
  var client = newHttpClient()
  var body = newMultipartData()
  body["method"] = "flickr.photos.search"
  body["api_key"] = apiKey
  body["tags"] = searchTags
  body["sort"] = "date-posted-desc"
  body["per_page"] = "500"
  body["extras"] = "license"

  var resp = client.post("https://api.flickr.com/services/rest/", multipart=body)
  if resp.status != "200 OK":
    raise newException(ValueError, "POST /rest/ status " & resp.status)

  try:
    var parsed = parseXml(resp.body)
    return parsed
  except XmlError:
    stderr.writeline("Malformed XML Response from flickr")
    quit(1)

proc checkPhoto(attrib: XmlNode): bool =
  # Check a single XML node to see if it can be posted
  # Check license info
  if attrib.attr("license") notin ["7", "9", "10"]:
    echo("Bad l")
    return false

  # Check we haven't posted it already, against a file, open as RW to create if not existing
  var fileStream = newFileStream("posted_id.txt", fmReadWrite)
  var line = ""
  while fileStream.readLine(line):
    if line == attrib.attr("id"):
      return false
  return true
  
when isMainModule:
  # load config file
  let config = loadConfig("twitter_bot.cfg")
  let flickrApiKey = config.getSectionValue("API", "flickrApiKey")
  let searchTags = config.getSectionValue("General", "searchTags")
  
  # do the search
  var search_xml = searchFlickr(flickrApiKey, searchTags)
  
  # Pick a random child index to try, otherwise try the next one
  var chosen: XmlNode
  while true:
    var index = rand(0..len(search_xml[0]))
    chosen = search_xml[0][index]
    if checkPhoto(chosen):
      break

  let tweetString = chosen.attr("title")
  echo(tweetString)
