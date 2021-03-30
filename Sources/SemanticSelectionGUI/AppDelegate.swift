import AppKit
import SwiftCoreNLP

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowDelegate = WindowDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appMenu = NSMenuItem()
        appMenu.submenu = NSMenu()
        appMenu.submenu?.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let mainMenu = NSMenu(title: "Semantic Text Editor")
        mainMenu.addItem(appMenu)
        NSApplication.shared.mainMenu = mainMenu

        let size = CGSize(width: 480, height: 270)
        let vc =  ViewController()
        let window = NSWindow(contentViewController: vc)
        vc.view.frame = .init(origin: .zero, size: CGSize(width: 100, height: 100))
        window.setContentSize(size)
        window.styleMask = [.closable, .miniaturizable, .resizable, .titled]
        window.delegate = windowDelegate
        window.title = "Semantic Text Editor"

        window.center()
        window.makeKeyAndOrderFront(window)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(0)
    }
}
