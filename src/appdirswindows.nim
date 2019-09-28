import os, system

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
    doAssert userDataDir("test_app", "test_company", "test_version",
      ).endsWith(".local/share/test_app/test_version")
    doAssert userConfigDir("app", "comp", "v1",
      ).endsWith(".config/app/v1")
    doAssert userCacheDir("app", "comp", "v1").endsWith(".cache/app/v1")
    doAssert userLogDir("app", "comp", "v1").endsWith(".cache/app/v1/log")
