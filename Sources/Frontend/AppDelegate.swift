import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowDelegate = WindowDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vc = ViewController()

        let appMenu = NSMenuItem()
        appMenu.submenu = NSMenu()
        appMenu.submenu?.items = [
            NSMenuItem(
                title: "Close", action: #selector(NSWindow.performClose(_:)),
                keyEquivalent: "w"),
            NSMenuItem(
                title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ]
        let mainMenu = NSMenu(title: "Semantic Text Editor")
        mainMenu.addItem(appMenu)

        let editMenu = NSMenuItem()
        editMenu.title = "Edit"
        editMenu.submenu = NSMenu(title: "Edit")
        editMenu.submenu?.items =
            [
                NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
                NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
                NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
                NSMenuItem.separator(),
                NSMenuItem(
                    title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"
                ),
                NSMenuItem.separator(),
            ]
            + [
                NSMenuItem(title: "Enter Selection Mode", action: nil, keyEquivalent: ""),
                NSMenuItem(title: "Select Sentence", action: nil, keyEquivalent: "s"),
                NSMenuItem(
                    title: "Select Parent Constituent",
                    action: #selector(vc.expandSelection),
                    keyEquivalent: String(format: "%C", NSUpArrowFunctionKey)),
                NSMenuItem(
                    title: "Refine Selection",
                    action: #selector(vc.focusSelection),
                    keyEquivalent: String(format: "%C", NSDownArrowFunctionKey)),
                NSMenuItem(
                    title: "Select Left Neighbour",
                    action: #selector(vc.selectLeftNeighbour),
                    keyEquivalent: String(format: "%C", NSLeftArrowFunctionKey)),
                NSMenuItem(
                    title: "Select Right Neighbour",
                    action: #selector(vc.selectRightNeighbour),
                    keyEquivalent: String(format: "%C", NSRightArrowFunctionKey)),
            ].map {
                $0.keyEquivalentModifierMask = .option
                return $0
            }

        mainMenu.addItem(editMenu)

        NSApplication.shared.mainMenu = mainMenu

        let size = CGSize(width: 480, height: 270)
        let window = NSWindow(contentViewController: vc)
        vc.view.frame = .init(origin: .zero, size: CGSize(width: 100, height: 100))
        window.setContentSize(size)
        window.styleMask = [.closable, .miniaturizable, .resizable, .titled]
        window.delegate = windowDelegate
        window.title = "Semantic Text Editor"
        if #available(macOS 11, *) {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
        }

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
