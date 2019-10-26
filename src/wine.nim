import dynlib

type
  getVersionProc = proc(): cstring {.gcsafe, stdcall.}

# https://www.winehq.org/pipermail/wine-devel/2008-September/069387.html
proc getWineVersion(): string =
  result = ""
  let dll = loadLib("ntdll.dll", true)
  if dll != nil:
    let getVersionAddr = dll.symAddr("wine_get_version")
    if getVersionAddr != nil:
      let getVersion = cast[getVersionProc](getVersionAddr)
      if getVersion != nil:
        result = $(getVersion())

proc detectWine*(): bool =
  result = getWineVersion() != ""

if isMainModule:
  if detectWine():
    echo "Running on Wine... ", getWineVersion()
  else:
    echo "Did not detect Wine."
