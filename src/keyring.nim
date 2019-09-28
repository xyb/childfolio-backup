import strutils

type
  KeyringError* = object of IOError
  NotFoundError* = object of KeyringError

proc getPassword*(serviceName, username: string): string
proc setPassword*(serviceName, username, password: string)
proc deletePassword*(serviceName, username: string)

when defined(macosx):
  import osproc, strformat

  const
    execPathKeychain = "/usr/bin/security"

  proc getPassword(serviceName, username: string): string =
    let cmd = fmt("{execPathKeychain} find-generic-password " &
        "-s {serviceName} -a {username} -w")
    let (output, exitCode) = execCmdEx(cmd)

    if exitCode != 0:
      if "could not be found" in output:
        raise newException(NotFoundError, output)
      else:
        raise newException(KeyringError, output)

    # TODO 密码中带有 \n 的会是特殊格式，需要处理
    result = output.strip()

  proc setPassword(serviceName, username, password: string) =
    let cmd = fmt("{execPathKeychain} add-generic-password " &
        "-U -s {serviceName} -a {username} -w {password}")
    let (output, exitCode) = execCmdEx(cmd)

    if exitCode != 0:
      raise newException(KeyringError, output)

  proc deletePassword*(serviceName, username: string) =
    let cmd = fmt("{execPathKeychain} delete-generic-password " &
        "-s {serviceName} -a {username}")
    let (output, exitCode) = execCmdEx(cmd)

    if exitCode != 0:
      raise newException(KeyringError, output)

when defined(windows):
  proc getPassword(serviceName, username: string): string =
    discard

  proc setPassword(serviceName, username, password: string) =
    discard

  proc deletePassword*(serviceName, username: string) =
    discard

when defined(linux):
  proc getPassword(serviceName, username: string): string =
    discard

  proc setPassword(serviceName, username, password: string) =
    discard

  proc deletePassword*(serviceName, username: string) =
    discard

when isMainModule:
  block baseTest:
    doAssertRaises(NotFoundError):
      discard getPassword("notexists", "notexists")
    setPassword("test", "test", "test")
    doAssert getPassword("test", "test") == "test"
    deletePassword("test", "test")
    doAssertRaises(NotFoundError):
      discard getPassword("test", "test")
