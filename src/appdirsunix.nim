import os, system

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
    doAssert userDataDir("test_app", "test_company", "test_version",
      ).endsWith(".local/share/test_app/test_version")
    doAssert userConfigDir("app", "comp", "v1",
      ).endsWith(".config/app/v1")
    doAssert userCacheDir("app", "comp", "v1").endsWith(".cache/app/v1")
    doAssert userLogDir("app", "comp", "v1").endsWith(".cache/app/v1/log")
