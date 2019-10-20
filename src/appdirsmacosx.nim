import os, strutils, system

proc userDir(baseDir, appName, appAuthor, version: string = ""): string =
  result = expandTilde(baseDir)
  if appName != "":
    result = joinPath(result, appName)

  if appName != "" and version != "":
    result = joinPath(result, version)

proc userDataDir(appName, appAuthor, version: string = "",
    roaming: bool = false): string =
  return userDir("~/Library/Application Support", appName, appAuthor, version)

proc userConfigDir(appName, appAuthor, version: string = "",
    roaming: bool = false): string =
  return userDataDir(appName, appAuthor, version, roaming)

proc userCacheDir(appName, appAuthor, version: string = "",
    opinion: bool = false): string =
  return userDir("~/Library/Caches", appName, appAuthor, version)

proc userLogDir(appName, appAuthor, version: string = "",
    opinion: bool = false): string =
  return userDir("~/Library/Logs", appName, appAuthor, version)


when isMainModule:
  block userDirTests:
    doAssert userDataDir("test_app", "test_company", "test_version",
      ).endsWith("Library/Application Support/test_app/test_version")
    doAssert userConfigDir("app", "comp", "v1",
      ).endsWith("Library/Application Support/app/v1")
    doAssert userCacheDir("app", "comp", "v1").endsWith("Library/Caches/app/v1")
    doAssert userLogDir("app", "comp", "v1").endsWith("Library/Logs/app/v1")
