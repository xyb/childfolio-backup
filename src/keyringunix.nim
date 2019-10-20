import appdirs, base64, os, strutils
import keyringerrors

# FIXME replace the naive implementation

proc getPassword(serviceName, username: string): string =
  let path = userConfigDir(serviceName, "", "")
  let configFile = joinPath(path, "account.conf")
  createDir(parentDir(configFile))
  if existsFile(configFile):
    let prefix = username & "="
    for line in open(configFile, fmRead).lines:
      if line.startsWith(prefix):
        result = line[prefix.len .. line.len-1]
        result = decode(result)
        return
  raise newException(NotFoundError, serviceName & " " & username)

proc updatePassword(serviceName, username, password: string,
    delete: bool = false) =
  let path = userConfigDir(serviceName, "", "")
  let configFile = joinPath(path, "account.conf")
  createDir(parentDir(configFile))

  var found = false
  var lines: seq[string]
  var prefix: string = username & "="
  if existsFile(configFile):
    for line in open(configFile, fmRead).lines:
      if line.startsWith(prefix):
        if delete:
          discard
        else:
          found = true
          lines.add(prefix & encode(password))
      else:
        lines.add(line)
  if not found and not delete:
    lines.add(prefix & encode(password))

  let conf = open(configFile, fmWrite)
  for line in lines:
    conf.writeLine(line)
  conf.close()

proc setPassword(serviceName, username, password: string) =
  updatePassword(serviceName, username, password, delete = false)

proc deletePassword(serviceName, username: string) =
  updatePassword(serviceName, username, password = "", delete = true)


when isMainModule:
  block baseTest:
    doAssertRaises(NotFoundError):
      discard getPassword("notexists", "notexists")
    setPassword("app", "user", "test")
    doAssert getPassword("app", "user") == "test"
    deletePassword("app", "user")
    doAssertRaises(NotFoundError):
      discard getPassword("app", "user")
