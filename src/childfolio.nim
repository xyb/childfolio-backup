import
  browsers, httpclient, json, options, os, rdstdin, sequtils, strformat,
  strutils, unicode, uri, terminal, times
import osproc

import markdown
import appdirs
import keyring
when defined(windows):
  import wine

when defined(profiler) or defined(memProfiler):
  import nimprof

const
  appName = "childfolio-backup"

  # 时光迹 API
  loginUrl = "http://familyapi.childfolio.cn" &
    "/FamilyServicesAPI/v1/api/user/logon"
  momentsUrl = "http://family.childfolio.cn" &
    "/Family/v1/api/Family/GetMomentList"

  # RFC 7232, section 2.2: Last-Modified, http
  lastModifiedFormat = "ddd, dd MMM yyyy HH:mm:ss 'GMT'"
  # ISO 8601 time format
  isoTimeFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"

  # emoji html entity
  speechBalloon = "&#x1F4AC;"
  threeOclock = "&#x1F552;"
  redHeart = "&#10084;&#65039;"

type
  Comment = object
    content: string
    author: string
    time: string

  Media = object
    url: string
    thumbnailUrl: string

  Child = object
    name: string
    nickName: string

  Moment = object
    id: string
    title: string
    time: string
    author: string
    child: seq[Child]
    className: string
    content: string
    pictures: seq[Media]
    video: Option[Media]
    audioAnnotationUrl: string
    likes: seq[string]
    comments: seq[Comment]

  Config = object
    account: string

proc newMedia(url, thumbnailUrl: string): Media =
  result = Media()
  result.url = url
  result.thumbnailUrl = thumbnailUrl

proc `%`(c: Comment): JsonNode =
  result = %[("content", %c.content), ("author", %c.author), ("time", %c.time)]

proc `%`(m: Media): JsonNode =
  result = %[("url", %m.url), ("thumbnail_url", %m.thumbnailUrl)]

proc `%`(c: Child): JsonNode =
  result = %[("name", %c.name), ("nickName", %c.nickName)]

proc `%`(m: Moment): JsonNode =
  result = %[("id", %m.id), ("title", %m.title), ("time", %m.time),
    ("author", %m.author), ("child", %m.child), ("class_name", %m.className),
    ("content", %m.content), ("pictures", %m.pictures), ("video", %m.video),
    ("audio_annotation_url", %m.audioAnnotationUrl), ("likes", %m.likes),
    ("comments", %m.comments)]

proc `%`(c: Config): JsonNode =
  result = %[("account", %c.account)]

proc decodeEscapedUnicode(str: string): string =
  ## Decode Unicode escape sequences.
  runnableExamples:
    doAssert decodeEscapedUnicode("\\u54c8") == "哈"

  try:
    let data = parseJson(str)
    result = parseJson(data["content"].str)["Content"].str
  except JsonParsingError:
    if "\\u" in str:
      let node = parseJson("\"" & str & "\"")
      result = node.str
    else:
      result = str
  except:
    raise

proc headOfWideString(s: string, count: int): string =
  ## Get first characters of a wide string
  runnableExamples:
    doAssert headOfWideString("你好，世界！", 3) == "你好，"
    doAssert headOfWideString("hello", 2) == "he"

  for (i, rune) in zip(toSeq(0 ..< count), toSeq(toRunes(s))):
    result &= $rune

proc normalTime(s: string): string =
  ## javascript's ISO 8601 time format to ISO 8601 UTC format
  runnableExamples:
    doAssert normalTime("2019-09-20T05:48:07.000Z") == "2019-09-20T05:48:07Z"

  result = s.replace(".000Z", "Z")

proc getConfigDir(): string =
  result = userConfigDir(appName, "", "")

proc getDataDir(): string =
  result = userDataDir(appName, "", "")

proc getFilename(path: string): string =
  ## Returns the file name and extension of the specified path string.
  runnableExamples:
    doAssert getFileInfo("/a/b/c.txt") == "c.txt"

  return splitPath(path).tail

proc login(account, password: string): tuple[userId: int, accessCode: string] =
  ## Login

  var client = newHttpClient(userAgent = "")
  var data = newMultipartData()
  data["User"] = account
  data["PWD"] = password
  data["AppId"] = "home"
  data["language"] = "zh-Hans"
  data["ExpiredSeconds"] = "7776000"
  data["AccountType"] = "0"
  client.headers = newHttpHeaders({"Accept": "application/json"})

  let response = client.post(loginUrl, multipart = data)
  if response.code() != Http200:
    quit("登录错误，请检查账号名称（邮箱或手机）和密码",
        QuitFailure)

  let node = parseJson(response.body)
  if not node["isSuccess"].getBool():
    quit("登录错误，请检查账号名称（邮箱或手机）和密码",
        QuitFailure)

  let userId = node["userId"].getInt()
  let accessCode = node["accessCode"]["accessCode"].getStr()
  return (userId, accessCode)

proc getMoments(userId: int, accessCode: string): seq[Moment] =
  ## Get moments
  var client = newHttpClient(userAgent = "")
  let form = encodeQuery({
    "UserId": $userId,
    "Counter": "0",
    "AccessCode": accessCode,
    "language": "zh-Hans",
  })
  client.headers.add("x-access-token", accessCode)
  client.headers.add("Content-Type", "application/x-www-form-urlencoded")
  client.headers.add("Accept", "application/json")
  # TODO 按照 Counter 获取下一页？
  let response = client.post(momentsUrl, body = form)

  if response.code() != Http200:
    quit("取孩子记录的时候出错啦", QuitFailure)

  let jsonDir = joinPath(getDataDir(), "moments")
  createDir(jsonDir)

  let data = parseJson(response.body)
  for node in data["data"]["momentInfoList"]:
    let id = node["momentId"].str
    let rawPath = joinPath(jsonDir, "$1.raw.json".format(id))
    let rawFile = open(rawPath, fmWrite)
    defer: rawFile.close()
    rawFile.write(node)

    var title, content: string
    if node.hasKey("momentCaptionExcerpt"):
      let captainNode = parseJson(node["momentCaptionExcerpt"].str)
      title = captainNode["title"].str
      content = captainNode["content"][0]["content"].str
    else:
      content = decodeEscapedUnicode(node["momentCaption"].str)
      const titleLimit = 10
      title = headOfWideString(content, titleLimit)
      if len(content) > titleLimit:
        title &= "..."

    let userNode = node["creatorInfo"]
    let username = userNode["lastName"].str & userNode["firstName"].str

    var video: Option[Media]
    let videoUrl = node["videoURL"].getStr()
    if videoUrl != "":
      video = some(newMedia(videoUrl, node["videoThumbnailURL"].str))
    else:
      video = none(Media)

    var pictures: seq[Media] = @[]
    if node.hasKey("pictureURLArr") and node["pictureURLArr"].kind == JArray:
      pictures = zip(node["pictureURLArr"].elems,
                     node["pictureThumbnailURLArr"].elems).mapIt(
                       newMedia(it[0].str, it[1].str))

    let moment = Moment(
      id: id,
      title: title,
      time: normalTime(node["publishedTime"].str),
      author: username,
      child: node["childInfo"].elems.mapIt(
        Child(name: it["lastName"].str & it["firstName"].str,
              nickName: decodeEscapedUnicode(it["nickName"].str))),
      className: node["className"].str,
      content: content,
      pictures: pictures,
      video: video,
      audioAnnotationUrl: node["audioAnnotationURL"].getStr(""),
      likes: node["momentLikeList"].elems.mapIt(it[
        "userModel"]["lastName"].str & it[
        "userModel"]["firstName"].str),
      comments: node["momentCommentList"].elems.mapIt(Comment(
          content: decodeEscapedUnicode(it["comment"].str),
          author: it["userModel"]["lastName"].str & it[
            "userModel"]["firstName"].str,
          time: normalTime(it["createdAt"].str))),
      )
    result.add(moment)

    let jsonPath = joinPath(jsonDir, "$1.json".format(moment.id))
    let jsonFile = open(jsonPath, fmWrite)
    defer: jsonFile.close()
    jsonFile.write(%moment)

proc formatMoment(moment: Moment): string =
  ## Fomrat moment as markdown
  let title = moment.title
  let author = moment.author
  let content = moment.content
  let dt = parse(moment.time, isoTimeFormat, utc())
  let time = dt.toTime().format("yyyy-MM-dd HH:mm:ss", local())
  let likes = join(moment.likes, " ")
  let pictures = join(moment.pictures.mapIt(
    "[![](thumbnails/$1)](pictures/$2)\L" % [getFilename(it.thumbnailUrl),
        getFilename(it.url)]))
  var video = ""
  if moment.video.isSome():
    video = "[![](thumbnails/$1)](videos/$2)\L" % [
        getFilename(moment.video.get.thumbnailUrl),
        getFilename(moment.video.get.url)]
  let comments = join(moment.comments.mapIt(
    speechBalloon & it.author & ": " & it.content), "\L\L")

  result = """# {title}
{threeOclock}{time} {author}

{content}

{pictures}

{video}

{redHeart}{likes}

{comments}
""".fmt

proc downloadFile(url: string, subDir: string = "") =
  ## Download file into data directory
  var client = newHttpClient(userAgent = "")
  var response: Response

  let dataDir = joinPath(getDataDir(), subDir)
  createDir(dataDir)
  let filename = getFilename(url)
  let path = joinPath(dataDir, filename)

  if fileExists(path):
    let size = getFileInfo(path).size
    response = client.head(url)
    if response.code() != Http200:
      # maybe deleted
      return
    if $size == response.headers["content-length"]:
      # skip downloads that have completed
      return
  else:
    # download again
    discard

  echo "下载 $1 ..." % [filename]
  when defined(windows):
    # bypass binary content issue on windows https://forum.nim-lang.org/t/5228
    let output = execProcess("powershell.exe",
        args = ["-ExecutionPolicy", "ByPass", "-File",
                "./download.ps1", url, path],
        options = {poStdErrToStdOut})
    if len(output) > 0:
      echo output
  else:
    let f = open(path, fmWrite)
    try:
      response = client.get(url)
      f.write(response.body)
    finally:
      # Do not defer close on writable file,
      # otherwise setLastModificationTime fruitless
      f.close()

    let modified = response.headers["Last-Modified"]
    let datetime = modified.parse(lastModifiedFormat, utc())
    path.setLastModificationTime(datetime.toTime)

proc dumpMoments(moments: seq[Moment]) =
  ## Dump moments as markdown and html files
  let dataDir = getDataDir()
  createDir(dataDir)
  let filename = joinPath(dataDir, "moments.md")
  var f = open(filename, fmWrite)
  defer: f.close()

  var content = ""
  for moment in moments:
    for pic in moment.pictures:
      downloadFile(pic.url, "pictures")
      downloadFile(pic.thumbnailUrl, "thumbnails")
    if moment.video.isSome():
      downloadFile(moment.video.get.url, "videos")
      downloadFile(moment.video.get.thumbnailUrl, "thumbnails")
    let s = formatMoment(moment)
    f.write(s)
    content.add s
  echo "保存孩子故事 $1 ..." % [filename]

  let htmlFilename = joinPath(dataDir, "moments.html")
  var htmlFile = open(htmlFilename, fmWrite)
  defer: htmlFile.close()
  let body = markdown(content)
  echo "保存孩子故事 $1 ..." % [htmlFilename]
  let html = """<!DOCTYPE html>
<html lang="en-US">
<head>
<title>时光迹备份</title>
<meta charset="utf-8">
<meta name="Description" content="时光迹备份。Childfolio backup. https://github.com/xyb/childfolio-backup">
<meta name="author" content="Xie Yanbo">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
{body}
</body>
</html>
""".fmt
  htmlFile.write(html)
  let uri = "file://" & htmlFilename
  openDefaultBrowser uri

proc readLineFromStdinDefault(prompt: string, default: string = "",
    isPassword: bool = false): string =
  ## Read a line from stdin.
  ##
  ## Return ``default`` if Enter pressed only,
  ## hide input characters if ``isPassword`` is ``true``.
  if isPassword:
    var readPasswordProc: proc(x: string): string = readPasswordFromStdin
    when defined(windows):
      if detectWine():
        # readPasswordFromStdin hang in wine
        readPasswordProc = readLineFromStdin

    if default != "":
      echo "$1 [或者直接回车输入已保存密码]:" % [prompt]
      result = readPasswordProc("[***]> ")
      if result == "":
        result = default
    else:
      echo "$1:" % [prompt]
      result = readPasswordProc("> ")
  else:
    if default != "":
      echo "$1 [或者直接回车输入上次账号]:" % [prompt]
      result = readLineFromStdin("[$1]> " % [default])
      if result == "":
        result = default
    else:
      echo "$1:" % [prompt]
      result = readLineFromStdin("> ")

proc loadConfig(): Config =
  let path = joinPath(getConfigDir(), "config.json")

  if existsFile(path):
    let configJson = parseJson(open(path, fmRead).readAll())
    result = to(configJson, Config)
  else:
    result = Config()
    result.account = ""

proc saveConfig(config: Config) =
  let path = joinPath(getConfigDir(), "config.json")
  createDir(parentDir(path))

  let configFile = open(path, fmWrite)
  defer: configFile.close()
  configFile.write(%config)

when isMainModule:
  var account, password: string = ""
  var config = loadConfig()

  account = readLineFromStdinDefault("输入时光迹用户账号（邮箱或手机号）",
      config.account)
  if config.account != account:
    config.account = account
    saveConfig(config)

  var saved_password = ""
  try:
    saved_password = getPassword(appName, account)
  except:
    saved_password = ""
  password = readLineFromStdinDefault("输入密码", saved_password,
      isPassword = true)

  let (userId, accessCode) = login(account, password)
  if saved_password != password:
    setPassword(appName, account, password)

  let moments = getMoments(userId, accessCode)
  dumpMoments(moments)
