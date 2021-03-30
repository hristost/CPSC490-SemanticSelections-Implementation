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
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textField.topAnchor.constraint(equalTo: view.topAnchor),
            textField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
