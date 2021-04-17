import AppKit
import Combine
import NLP
import SwiftCoreNLP

class SemanticTextView: NSTextView {
    /// Parsed text
    ///
    /// - Note: Not always up-to-date
    var parse: Constituent? = nil
    /// Desired selection level in the constituent tree, where 0 = complete sentence
    var selectionLevel: Int = 10
    var subscription: Set<AnyCancellable> = []

    init() {
        super.init(frame: .zero)
        /// CoreNLP server we use for parsing
        let NLPServer = Parser.shared!

        NotificationCenter.default
            // Listen for text changes
            .publisher(for: NSText.didChangeNotification, object: self)
            // Wait so the language server is not overwhelmed
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            // Parse
            .compactMap { ($0.object as? NSText)?.string }
            .setFailureType(to: Parser.SuParError.self)  // this is required for iOS 13
            .tryMap { try NLPServer.parse($0) }
            // Sometimes, we receive parses for outdated text. Checking the length suffices to
            // prevent crashes when highlighting, and any incorrect parsing is quickly resolved with
            // the next parse
            //.filter { self.textStorage!.length == $0.length }
            // Update state
            .receive(on: DispatchQueue.main)
            .sink { notification in
                print("NOTF", notification)
            } receiveValue: { tree in
                print("RECV", tree)
                self.parse = tree
                self.highlight(tree: tree)
            }
            .store(in: &self.subscription)
    }

    // Additional initializers just so everything compiles
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: textContainer)
    }

    override func flagsChanged(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.flagsChanged(with: event)
            return
        }
        selectionMode(using: .trackpad)
    }

    override func otherMouseDown(with event: NSEvent) {
        // When the tertiary mouse button (i.e. wheel button) is pressed, we enter selection mode:
        // - Moving the mouse selects a constituent under the cursor
        // - Scrolling up or down using the scroll wheel expands or shrinks the selection
        selectionMode(using: .mouse)
    }

    /// Start selection mode
    enum SelectionInteraction { case mouse, trackpad }
    func selectionMode(using mode: SelectionInteraction) {
        print("Enter selection mode")
        var magnification: CGFloat = 0
        let events = NSEvent.EventTypeMask([
            .mouseMoved,
            .otherMouseDragged,
        ])
        .union(
            (mode == .mouse ? [.scrollWheel, .otherMouseUp] : [.flagsChanged, .magnify])
        )

        poll: while true {
            guard
                let event = self.window?.nextEvent(matching: events)
            else { continue }

            switch event.type {
            case .otherMouseUp:
                break poll
            case .flagsChanged:
                if !event.modifierFlags.contains(.command) {
                    break poll
                }

            case .scrollWheel:
                let direction = event.deltaY > 0 ? 1 : -1
                self.selectionLevel += direction
            case .magnify:
                magnification += event.magnification
                if abs(magnification) > 0.1 {
                    let direction = magnification < 0 ? 1 : -1
                    self.selectionLevel += direction
                    self.selectionLevel = max(self.selectionLevel, 0)
                    magnification = 0
                }

            default:
                ()
            }

            let location = self.convert(event.locationInWindow, from: nil)
            self.selectionLevel = max(self.selectionLevel, 0)

            let offset = self.characterIndexForInsertion(at: location)
            let mouseRange = NSMakeRange(offset, 1)
            if let selection = parse?.findChild(containing: mouseRange, at: self.selectionLevel) {
                let start = selection.offset
                let selectionRange = NSMakeRange(start, Int(selection.child.length))
                self.setSelectedRange(selectionRange)
                self.selectionLevel = selection.depth - 1
                self.selectionLevel = max(self.selectionLevel, 0)
            }

        }
        print("End selection mode")
    }

    func highlight(tree: Constituent, offset: Int = 0, level: Int = 0) {
        guard let text = self.textStorage else { return }
        if tree.children.isEmpty {
            let start = tree.offset
            let length = tree.length
            let range = NSMakeRange(Int(start) + offset, Int(length))
            let alpha = max(0.2, 1 - CGFloat(level) / 9)
            let color = NSColor.labelColor.withAlphaComponent(alpha)
            let totalLength = self.attributedString().length
            if totalLength > 0 {
                assert(range.lowerBound <= totalLength)
                assert(range.upperBound <= totalLength)
            }
            text.addAttribute(.foregroundColor, value: color, range: range)
        } else {
            tree.children.forEach {
                highlight(tree: $0, offset: offset + Int(tree.offset), level: level + 1)
            }
        }
    }
}
