import httpclient, xmlparser, xmltree, random, parsecfg

proc searchFlickr(): XmlNode =
  # Create a httpClient and get a search for 500 images
  var client = newHttpClient()
  var body = newMultipartData()
  body["method"] = "flickr.photos.search"
  body["api_key"] = "dothislater"
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
    return false
  # Check we haven't posted it already, against a file
  
when isMainModule:
  var search_xml = searchFlickr()
  
  # Pick a random child index to try
  while true:
    let index = rand(0..len(search_xml))
    if checkPhoto(search_xml[index]):
      break
