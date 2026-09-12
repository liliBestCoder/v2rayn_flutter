import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    AppDelegate.cleanProxyAndKillProcesses()
    super.applicationWillTerminate(notification)
  }

  static func killCoreProcesses() {
    // 1. Force kill any running luxwap_core core processes
    let killTask = Process()
    killTask.launchPath = "/usr/bin/pkill"
    killTask.arguments = ["-9", "-f", "luxwap_core"]
    try? killTask.run()
    killTask.waitUntilExit()
  }

  static func cleanSystemProxyOnly() {
    // 2. Restore macOS network services proxy states (Wi-Fi, Ethernet, Thunderbolt Bridge)
    let interfaces = ["Wi-Fi", "Ethernet", "Thunderbolt Bridge"]
    for iface in interfaces {
      let webTask = Process()
      webTask.launchPath = "/usr/sbin/networksetup"
      webTask.arguments = ["-setwebproxystate", iface, "off"]
      try? webTask.run()

      let secureTask = Process()
      secureTask.launchPath = "/usr/sbin/networksetup"
      secureTask.arguments = ["-setsecurewebproxystate", iface, "off"]
      try? secureTask.run()

      let socksTask = Process()
      socksTask.launchPath = "/usr/sbin/networksetup"
      socksTask.arguments = ["-setsocksfirewallproxystate", iface, "off"]
      try? socksTask.run()
    }
  }

  static var activeTunNodeIp: String?

  static func cleanTunNodeRoute() {
    guard let nodeIp = activeTunNodeIp, !nodeIp.isEmpty else { return }
    let routeTask = Process()
    routeTask.launchPath = "/sbin/route"
    routeTask.arguments = ["delete", "-host", nodeIp]
    try? routeTask.run()
    routeTask.waitUntilExit()
    activeTunNodeIp = nil
  }

  static func cleanProxyAndKillProcesses() {
    killCoreProcesses()
    cleanTunNodeRoute()
    cleanSystemProxyOnly()
  }
}
