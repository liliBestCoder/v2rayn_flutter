import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Set initial window size to match the login page design (420×760).
    // Center the window on the screen.
    let width: CGFloat = 420
    let height: CGFloat = 760
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let x = screenFrame.midX - width / 2
      let y = screenFrame.midY - height / 2
      self.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    } else {
      self.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: true)
    }

    // Prevent resizing smaller than the designed login size.
    self.minSize = NSSize(width: 420, height: 760)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
