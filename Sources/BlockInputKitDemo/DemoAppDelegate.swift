import AppKit

@MainActor
final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: DemoWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        let windowController = DemoWindowController()
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        self.windowController = windowController
        activateDemoApp()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit \(ProcessInfo.processInfo.processName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = NSApp
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func activateDemoApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
