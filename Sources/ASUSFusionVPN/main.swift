import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuController = MenuBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuController = nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
