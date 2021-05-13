import AppKit
import Backend

class ViewController: NSViewController, NSTextViewDelegate {
    let textField = SemanticTextView()

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true

        textField.minSize = .init(width: 0, height: 300)
        textField.maxSize = .init(width: .max, height: .max)

        textField.isHorizontallyResizable = false
        textField.isVerticallyResizable = true

        textField.textContainer?.heightTracksTextView = false

        textField.autoresizingMask = .width

        scrollView.documentView = textField

        self.view = scrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        if #available(OSX 11.0, *) {
            if let fontDesc =
                NSFontDescriptor
                .preferredFontDescriptor(forTextStyle: .body)
                .withDesign(.serif)
            {
                let font = NSFont.init(descriptor: fontDesc, size: 24)
                textField.font = font
            }
        }

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        textField.insertText(janet, replacementRange: NSRange(location: 0, length: 0))

    }

    override func viewDidLayout() {
        super.viewWillLayout()

        if #available(macOS 11, *) {
            let titleBarHeight = self.view.safeAreaInsets.top
            textField.textContainerInset = .init(width: 10, height: titleBarHeight)
        }
    }

    @objc func expandSelection() {
        textField.expandSelection()
    }
    @objc func selectSentence() {
        textField.selectSentence()
    }
    @objc func focusSelection() {
        textField.focusSelection(at: -1)
    }
    @objc func selectLeftNeighbour() {
        textField.selectLeftNeighbour()
    }
    @objc func selectRightNeighbour() {
        textField.selectRightNeighbour()
    }
    @objc func disableHighlighting() {
        textField.colors = .none
    }
    @objc func colorSchemeMenuSelection(sender: NSMenuItem) {
        textField.colors = colorSchemes[sender.title] ?? .none
    }
    @objc func changeLanguageMenu(sender: NSMenuItem) {
        guard
            let language = Parser.Language.allCases.first(where: {$0.name() == sender.title })
        else { return }
        Parser.shared?.language = language

        let range = 0..<textField.string.count
        switch language {
            case .english, .english_roberta:
            textField.insertText(janet, replacementRange: NSRange(range))
            case .chinese:
            textField.insertText(chinese, replacementRange: NSRange(range))
        }

    }
}
