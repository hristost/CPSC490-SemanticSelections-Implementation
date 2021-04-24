import AppKit
import Combine
import NLP

extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

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

            let location = self.convert(event.locationInWindow, from: nil)
            let offset = self.characterIndexForInsertion(at: location)

            switch event.type {
            case .otherMouseUp:
                break poll
            case .flagsChanged:
                if !event.modifierFlags.contains(.command) {
                    break poll
                }

            case .scrollWheel:
                event.deltaY < 0 ? self.expandSelection() : self.focusSelection(at: offset)
            case .magnify:
                magnification += event.magnification
                if abs(magnification) > 0.1 {
                    magnification > 0 ? expandSelection() : focusSelection(at: offset)
                    magnification = 0
                }
            default:
                let mouseRange = offset..<(offset + 1)
                if let selection = parse?.findChild(containing: mouseRange, at: self.selectionLevel)
                {
                    let start = selection.offset
                    let selectionRange = NSMakeRange(start, Int(selection.child.length))
                    self.setSelectedRange(selectionRange)
                    self.selectionLevel = selection.child.level - 1
                    self.selectionLevel = max(self.selectionLevel, 0)
                }
            }

        }
        print("End selection mode")
    }

    func highlight(tree: Constituent, offset: Int = 0) {
        guard let text = self.textStorage else { return }
        if tree.children.isEmpty {
            let start = tree.offset
            let length = tree.length
            let range = NSMakeRange(Int(start) + offset, Int(length))
            let alpha = max(0.2, 1 - CGFloat(tree.level) / 9)
            let color = NSColor.labelColor.withAlphaComponent(alpha)
            let totalLength = self.attributedString().length
            if totalLength > 0 {
                assert(range.lowerBound <= totalLength)
                assert(range.upperBound <= totalLength)
            }
            text.addAttribute(.foregroundColor, value: color, range: range)
        } else {
            tree.children.forEach {
                highlight(tree: $0, offset: offset + Int(tree.offset))
            }
        }
    }

    /// Expand the current selection to the nearest constituent that has greater length
    func expandSelection() {
        guard
            let range = Range(self.selectedRange()),
            var constituent = parse?.descendant(containing: range)
        else { return }

        if range.count == constituent.length, let parent = constituent.parent {
            // If the selection lines up with a constituent, select its parent constituent
            constituent = parent
        }
        self.setSelectedRange(.init(constituent.absoluteRange))
        self.selectionLevel = constituent.level

        var node = constituent
        while let parent = node.parent {
            parent.lastFocus = node
            node = parent
        }
    }

    /// Shrinks the current selection to a descendant constituent that contains the given character
    /// index. If the index is outside the current selection, the first or last child constituent
    /// will be selected.
    ///
    /// - Parameter centerIndex: index of the character that should remain in the selection
    func focusSelection(at centerIndex: Int) {
        guard
            let range = Range(self.selectedRange()),
            let constituent = parse?.descendant(containing: range)
        else { return }

        let cursor = centerIndex - constituent.absoluteRange.lowerBound
        let cursorClamped =
            centerIndex.clamped(to: constituent.absoluteRange)
            - constituent.absoluteRange.lowerBound

        if let child =
            constituent.children.first(where: { $0.range.contains(cursor) })
            ?? constituent.lastFocus
            ?? constituent.children.first(where: { $0.range.contains(cursorClamped) })
        {
            self.setSelectedRange(.init(child.absoluteRange))
            self.selectionLevel = child.level
            var node = child
            while let parent = node.parent {
                parent.lastFocus = node
                node = parent
            }
        }
    }
}
