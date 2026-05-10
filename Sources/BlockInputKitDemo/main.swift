import AppKit
import BlockInputKit

final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let editorView = BlockInputView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        editorView.wantsLayer = true
        editorView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BlockInputKit Demo"
        window.center()
        window.contentView = editorView
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = DemoAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
