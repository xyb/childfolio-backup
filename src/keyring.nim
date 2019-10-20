proc getPassword*(serviceName, username: string): string
proc setPassword*(serviceName, username, password: string)
proc deletePassword*(serviceName, username: string)

when defined(macosx):
  include keyringmacosx

# FIXME
#elif defined(windows):
#  include keyringwindows

elif defined(linux):
  include keyringunix

else:
  include keyringunix

when isMainModule:
  block baseTest:
    doAssertRaises(NotFoundError):
      discard getPassword("notexists", "notexists")
    setPassword("app", "user", "test")
    doAssert getPassword("app", "user") == "test"
    deletePassword("app", "user")
    doAssertRaises(NotFoundError):
      discard getPassword("app", "user")
