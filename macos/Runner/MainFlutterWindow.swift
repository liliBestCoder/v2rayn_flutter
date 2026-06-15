import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Set initial window size to match the login page design (420×760).
    // Center the window on the screen.
    let initialWidth: CGFloat = 420
    let initialHeight: CGFloat = 760
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let x = screenFrame.midX - initialWidth / 2
      let y = screenFrame.midY - initialHeight / 2
      self.setFrame(NSRect(x: x, y: y, width: initialWidth, height: initialHeight), display: true)
    } else {
      self.setFrame(NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight), display: true)
    }

    // Prevent resizing smaller than the designed login size.
    self.minSize = NSSize(width: 420, height: 760)

    // Register window resize channel so Flutter can resize the window
    // (e.g. from login 420×760 to main shell 1194×850).
    let windowChannel = FlutterMethodChannel(
      name: "luxwap/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "setSize":
        guard let args = call.arguments as? [String: Any],
              let width = args["width"] as? Double,
              let height = args["height"] as? Double else {
          result(FlutterError(code: "INVALID_ARGS", message: "width/height required", details: nil))
          return
        }
        let center = args["center"] as? Bool ?? false
        var frame = self.frame
        frame.size = NSSize(width: width, height: height)
        if center, let screen = NSScreen.main {
          let screenFrame = screen.visibleFrame
          frame.origin.x = screenFrame.midX - width / 2
          frame.origin.y = screenFrame.midY - height / 2
        }
        self.setFrame(frame, display: true, animate: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
