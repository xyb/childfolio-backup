import os, strutils, system

proc userDir(baseDir, appName, appAuthor: string = "",
    version: string = ""): string =
  let path = getEnv("XDG_DATA_HOME", "")
  if path == "":
    result = expandTilde(baseDir)
  if appName != "":
    result = joinPath(result, appName, version)

proc userDataDir(appName, appAuthor, version: string = "",
    roaming: bool = false): string =
  return userDir("~/.local/share", appName, appAuthor, version)

proc userConfigDir(appName, appAuthor, version: string = "",
    roaming: bool = false): string =
  return userDir("~/.config", appName, appAuthor, version)

proc userCacheDir(appName, appAuthor, version: string = "",
    opinion: bool = false): string =
  return userDir("~/.cache", appName, appAuthor, version)

proc userLogDir(appName, appAuthor, version: string = "",
    opinion: bool = false): string =
  return joinPath(userCacheDir(appName, appAuthor, version, opinion), "log")


when isMainModule:
  block userDirTests:
    doAssert userDir("base", "app", "comp", "v1").endsWith("base/app/v1")
    doAssert userDataDir("app", "company", "v1").endsWith(".local/share/app/v1")
    doAssert userConfigDir("app", "comp", "v1").endsWith(".config/app/v1")
    doAssert userCacheDir("app", "comp", "v1").endsWith(".cache/app/v1")
    doAssert userLogDir("app", "comp", "v1").endsWith(".cache/app/v1/log")
