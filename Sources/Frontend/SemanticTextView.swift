import AppKit
import Backend
import Combine
import NLP

extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}


extension Optional {
    func makeNil(if cond: Bool) -> Wrapped? {
        cond ? nil : self
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
            .setFailureType(to: Error.self)  // this is required for iOS 13
            .flatMap { NLPServer.parse($0) }
            // Sometimes, we receive parses for outdated text. Checking the hash suffices to
            // prevent crashes when highlighting
            .filter { self.textStorage?.string.hashValue == $0.hash }
            // Update state
            .receive(on: DispatchQueue.main)
            .sink { _ in
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

    override func otherMouseDown(with event: NSEvent) {
        // When the tertiary mouse button (i.e. wheel button) is pressed, we enter selection mode:
        // - Moving the mouse selects a constituent under the cursor
        // - Scrolling up or down using the scroll wheel expands or shrinks the selection
        selectionMode(using: .mouse)
    }

    override func selectionRange(forProposedRange proposedCharRange: NSRange, granularity: NSSelectionGranularity) -> NSRange {
        let range = super.selectionRange(forProposedRange: proposedCharRange, granularity: granularity)
        print(proposedCharRange, granularity.rawValue, range)
        return range
    }

    /// Start selection mode
    enum SelectionInteraction { case mouse, trackpad }
    func selectionMode(using mode: SelectionInteraction) {
        print("Enter selection mode")

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
            case .scrollWheel:
                event.deltaY < 0 ? self.expandSelection() : self.focusSelection(at: offset)
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

    var magnification: CGFloat = 0
    override func magnify(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        let offset = self.characterIndexForInsertion(at: location)

        magnification += event.magnification
        if abs(magnification) > 0.1 {
            magnification > 0 ? expandSelection() : focusSelection(at: offset, ignoreHistory: true)
            magnification = 0
        }
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

        self.select(constituent)
    }

    /// Shrinks the current selection to a descendant constituent that contains the given character
    /// index. If the index is outside the current selection, the first or last child constituent
    /// will be selected.
    ///
    /// - Parameter centerIndex: index of the character that should remain in the selection
    func focusSelection(at centerIndex: Int, ignoreHistory: Bool = false) {
        guard
            let range = Range(self.selectedRange()),
            let constituent = parse?.descendant(containing: range)
        else { return }

        let cursor = centerIndex - constituent.absoluteRange.lowerBound
        let cursorClamped = min(
            centerIndex.clamped(to: constituent.absoluteRange)
            - constituent.absoluteRange.lowerBound,
            constituent.length - 1)
        print("focus at \(centerIndex)", cursor, cursorClamped)

        if let child =
            constituent.children.first(where: { $0.range.contains(cursor) })
            ?? constituent.lastFocus.makeNil(if: ignoreHistory)
            ?? constituent.children.first(where: { $0.range.contains(cursorClamped) })
        {
            self.select(child)
        }
    }

    func selectLeftNeighbour() {
        guard
            let range = Range(self.selectedRange()),
            let constituent = parse?.descendant(containing: range),
            range.count == constituent.length,
            let neighbour = constituent.leftNeighbour()
        else { return }

        self.select(neighbour)
    }

    func selectRightNeighbour() {
        guard
            let range = Range(self.selectedRange()),
            let constituent = parse?.descendant(containing: range),
            range.count == constituent.length,
            let neighbour = constituent.rightNeighbour()
        else { return }

        self.select(neighbour)
    }

    func selectSentence() {
        guard
            let range = Range(self.selectedRange()),
            var node = parse?.descendant(containing: range)
        else { return }

        while node.value != "TOP", let parent = node.parent {
            node = parent
        }

        if node.value == "TOP" {
            self.select(node)
        }
    }

    private func select(_ span: Constituent) {
        self.setSelectedRange(.init(span.absoluteRange))
        self.selectionLevel = span.level

        var node = span
        while let parent = node.parent {
            parent.lastFocus = node
            node = parent
        }
    }
}
