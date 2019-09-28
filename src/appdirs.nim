## Utilities for determining application-specific dirs.
## Inprised by https://github.com/ActiveState/appdirs

import os, system

proc userDataDir*(appName, appAuthor, version: string = "",
    roaming: bool = false): string
  ## Full path to the user-specific data dir for this application.
proc userConfigDir*(appName, appAuthor, version: string = "",
    roaming: bool = false): string
  ## Full path to the user-specific config dir for this application.
proc userCacheDir*(appName, appAuthor, version: string = "",
    opinion: bool = false): string
  ## Full path to the user-specific cache dir for this application.
proc userLogDir*(appName, appAuthor, version: string = "",
    opinion: bool = false): string
  ## Full path to the user-specific log dir for this application.

when defined(macosx):
  include appdirsmacosx

elif defined(windows):
  include appdirswindows

elif defined(linux):
  include appdirsunix

else:
  include appdirsunix
