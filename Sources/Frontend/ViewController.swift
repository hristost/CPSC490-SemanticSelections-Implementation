import AppKit

class ViewController: NSViewController, NSTextViewDelegate {
    let textField = SemanticTextView()

    override func loadView() {
        self.view = NSView()
        self.view.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false

        if #available(OSX 11.0, *) {
            if let fontDesc =
                NSFontDescriptor
                .preferredFontDescriptor(forTextStyle: .headline)
                .withDesign(.serif)
            {
                let font = NSFont.init(descriptor: fontDesc, size: 24)
                textField.font = font
            }
        }

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            //textField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            //textField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            //textField.topAnchor.constraint(equalTo: view.topAnchor),
            //textField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        textField.insertText("""
        The quick brown fox jumped over the lazy dog.
        I went to Stop and Shop and bought some milk, oranges that I will use to squeeze orange\
        juice, flour that will go in banana bread, and some vegetables.
        """, replacementRange: NSRange(location: 0, length: 0))

    }

    override func viewDidLayout() {
        super.viewWillLayout()
        textField.frame = view.bounds
        if #available(macOS 11, *) {
            let titleBarHeight = self.view.safeAreaInsets.top
            textField.textContainerInset = .init(width: 10, height: titleBarHeight)
        }
        //textField.c

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

}
