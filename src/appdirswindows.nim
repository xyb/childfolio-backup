import strutils, system

# FIXME

proc userDataDir(appName, appAuthor, version: string = "",
    roaming: bool = false): string =
  discard

proc userConfigDir(appName, appAuthor, version: string = "",
    roaming: bool = false): string =
  discard

proc userCacheDir(appName, appAuthor, version: string = "",
    opinion: bool = false): string =
  discard

proc userLogDir(appName, appAuthor, version: string = "",
    opinion: bool = false): string =
  discard


when isMainModule:
  block userDirTests:
    doAssert userDataDir("app", "company", "v1").endsWith(".local/share/app/v1")
    doAssert userConfigDir("app", "comp", "v1").endsWith(".config/app/v1")
    doAssert userCacheDir("app", "comp", "v1").endsWith(".cache/app/v1")
    doAssert userLogDir("app", "comp", "v1").endsWith(".cache/app/v1/log")
