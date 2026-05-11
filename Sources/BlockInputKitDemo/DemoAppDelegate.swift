import AppKit

@MainActor
final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: DemoWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowController = DemoWindowController()
        windowController.showWindow(nil)
        self.windowController = windowController
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
