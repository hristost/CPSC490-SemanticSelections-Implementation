import AppKit
import Backend
import Carbon.HIToolbox
import Combine
import NLP

class SemanticTextView: NSTextView {
    enum SelectionDirection {
        case left, right
        func negated() -> SelectionDirection {
            return self == .left ? .right : .left
        }
    }

    /// Parsed text
    ///
    /// - Note: Not always up-to-date
    var parse: Constituent? = nil
    /// Desired selection level in the constituent tree, where 0 = complete sentence
    var selectionLevel: Int = 10

    /// The colour scheme for showing constituents
    var colors: Highlight = colorSchemes.values.first ?? .none {
        didSet {
            self.highlight()
        }
    }

    var subscription: Set<AnyCancellable> = []
    var lastAnchorPoint: Range<Int> = 0..<1
    var selectionDirection: SelectionDirection = .right

    init() {
        super.init(frame: .zero)
        /// CoreNLP server we use for parsing
        let NLPServer = Parser.shared!

        NotificationCenter.default
            // Listen for text changes
            .publisher(for: NSText.didChangeNotification, object: self)
            // Wait so the language server is not overwhelmed
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .compactMap { ($0.object as? NSText)?.string }
            // Don't parse if the text hasn't changed since last parse
            .filter { $0.hashValue != self.parse?.hash }
            // Parse
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
                self.highlight()
            }
            .store(in: &self.subscription)

        NotificationCenter.default
            .publisher(for: NSTextView.didChangeSelectionNotification, object: self)
            .filter { _ in self.textStorage?.string.hashValue == self.parse?.hash }
            .receive(on: DispatchQueue.main)
            .sink { _ in
                self.highlight()
            }
            .store(in: &self.subscription)

        self.delegate = self
    }

    // Additional initializers just so everything compiles
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: textContainer)
    }

    override func setSelectedRange(
        _ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool
    ) {
        // Override so we can keep track of selection direction (see SelectionDirection.swift)
        if charRange.length == 0, let anchor = Range(charRange) {
            self.lastAnchorPoint = anchor
        }
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
    }

    override func keyDown(with event: NSEvent) {
        let leftArrow = event.keyCode == kVK_LeftArrow
        let rightArrow = event.keyCode == kVK_RightArrow
        let movement: SelectionDirection = leftArrow ? .left : .right
        let range = self.trimmedSelection()

        if event.modifierFlags.contains([.shift, .option]),
            leftArrow || rightArrow,
            let modifiedRange = self.modifiedSelection(range, movementDirection: movement)
        {
            // We are augmenting / trimming selection using shift + alt + left/right
            self.setSelectedRange(.init(modifiedRange))
        } else if event.modifierFlags.contains(.option),
            !event.modifierFlags.contains(.shift),
            leftArrow || rightArrow,
            let newSelection = self.newSelection(range, movementDirection: movement)
        {
            // We are selecting a neighbour node using alt + left/right
            self.select(newSelection)
        } else {
            super.keyDown(with: event)
        }

    }

    override func mouseDown(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        let offset = self.characterIndexForInsertion(at: location)
        let range = self.trimmedSelection()
        if event.modifierFlags.contains([.shift, .option]),
            let newSelection = self.modifiedSelection(
                range,
                toInclude: offset)
        {
            // If the user clicks while holding shift and alt on the keyboard, try adjusting the
            // selection to snap a constituent
            self.setSelectedRange(.init(newSelection))
        } else if Parser.shared!.language == .english && event.clickCount == 4 {
            // When the user clicks three times, we assume they want to select a paragraph
            let paragraph = selectionRange(
                forProposedRange: .init(location: offset, length: 0),
                granularity: NSSelectionGranularity(rawValue: 4)!)
            self.setSelectedRange(paragraph)

        } else if Parser.shared!.language == .chinese && event.clickCount > 1 {
            // Since we don't support more than one sentence in Chinese, a triple click would always
            // result in everything being selected. For added utility, we override every additional
            // click to expand the selection
            self.expandSelection()

        } else {
            super.mouseDown(with: event)
        }
    }

    override func otherMouseDown(with event: NSEvent) {
        // When the tertiary mouse button (i.e. wheel button) is pressed, we enter selection mode:
        // - Moving the mouse selects a constituent under the cursor
        // - Scrolling up or down using the scroll wheel expands or shrinks the selection

        let events: NSEvent.EventTypeMask = [
            .mouseMoved, .otherMouseDragged, .scrollWheel, .otherMouseUp,
        ]

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
    }

    var magnification: CGFloat = 0
    override func magnify(with event: NSEvent) {
        // Make the pinch out / pinch in gestures expand / trim the current selection
        let location = self.convert(event.locationInWindow, from: nil)
        let offset = self.characterIndexForInsertion(at: location)

        magnification += event.magnification
        if abs(magnification) > 0.1 {
            magnification > 0 ? expandSelection() : focusSelection(at: offset, ignoreHistory: true)
            magnification = 0
        }
    }

    override func selectionRange(
        forProposedRange proposedCharRange: NSRange, granularity: NSSelectionGranularity
    ) -> NSRange {
        // Override so we can triple-click to select a sentence
        //
        // Ideally, this should also modify consequent modifications using the shift key + arrow
        // key or shift key + mouse click. But the value returned by this function is never used..?
        switch granularity {
        case .selectByCharacter, .selectByWord:
            // Default
            return super.selectionRange(
                forProposedRange: proposedCharRange,
                granularity: granularity)

        case .selectByParagraph:
            // The "Select by paragraph" mode is activated with three clicks. We change it to
            // mean "Select by sentence"
            if let range = Range(proposedCharRange),
                let node = self.parse?
                    .descendant(containing: range)?
                    .sentenceAncestor()
            {
                return .init(node.absoluteRange)
            }

            return super.selectionRange(
                forProposedRange: proposedCharRange,
                granularity: granularity)

        default:
            // A value other than the three default ones is something we set ourselves using
            // .init(rawValue). We assume that to mean "Select by paragraph"
            return super.selectionRange(
                forProposedRange: proposedCharRange, granularity: .selectByParagraph)
        }
    }

    func constituentContainingSelection() -> Constituent? {
        guard
            let range = Range(self.selectedRange()),
            var constituent = parse?.descendant(containing: range)
        else { return nil }

        if range.count == constituent.length, constituent.value != "TOP",
            constituent.value != "DOC", let parent = constituent.parent
        {
            // If the selection lines up with a constituent, select its parent constituent
            constituent = parent
        }
        return constituent.value != "DOC" ? constituent : nil
    }

    /// Expand the current selection to the nearest constituent that has greater length
    func expandSelection() {
        if let node = self.constituentContainingSelection() {
            self.select(node)
        }
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

        if let child =
            constituent.children.first(where: { $0.range.contains(cursor) })
            ?? constituent.lastFocus.makeNil(if: ignoreHistory)
            ?? constituent.children.first(where: { $0.range.contains(cursorClamped) })
        {
            self.select(child)
        }
    }

    /// Select the sentence that encloses the current selection
    func selectSentence() {
        guard
            let range = Range(self.selectedRange()),
            let node = parse?.descendant(containing: range)?.sentenceAncestor()
        else { return }

        self.select(node)
    }
}

fileprivate extension SemanticTextView {

    /// Set the current selection to the constituent's span, and update `lastFocus` on ancestors
    func select(_ span: Constituent) {
        self.setSelectedRange(.init(span.absoluteRange))
        self.selectionLevel = span.level

        var node = span
        while let parent = node.parent {
            parent.lastFocus = node
            node = parent
        }
    }

    /// The constituent to be selected after moving left or right from a range
    func newSelection(_ range: Range<Int>, movementDirection: SelectionDirection) -> Constituent? {
        guard
            let node = parse?.descendant(containing: range),
            node.length == range.count
        else { return nil }
        return movementDirection == .left ? node.leftNeighbour() : node.rightNeighbour()
    }

    /// The given range, extended or trimmed so that it contains the given offset
    func modifiedSelection(_ range: Range<Int>, toInclude x: Int) -> Range<Int>? {

        if range.contains(x) {
            // Trim
            var range = range
            while range.contains(x),
                let next = modifiedSelection(
                    range, movementDirection: self.selectionDirection.negated()),
                next.contains(x)

            {
                range = next
            }
            return range.contains(x) ? range : nil

        } else {
            // Expand
            self.selectionDirection = x < range.lowerBound ? .left : .right
            var range = range
            while !range.contains(x),
                let next = modifiedSelection(range, movementDirection: self.selectionDirection)
            {
                range = next
            }
            return range.contains(x) ? range : nil
        }
    }

    /// The current range, extended or trimmed by moving a constituent left or right
    func modifiedSelection(_ range: Range<Int>, movementDirection: SelectionDirection) -> Range<Int>? {

        guard let (leftBoundary, rightBoundary) = self.parse?.findBoundaryNodes(for: range) else {
            return nil
        }
        let level = max(leftBoundary.level, rightBoundary.level)

        switch (movementDirection, selectionDirection, leftBoundary == rightBoundary) {
        case (.left, .left, _):
            // Expand left
            if let next = leftBoundary.leftNeighbour(atLevel: level) {
                return next.absoluteRange.lowerBound..<range.upperBound
            }

        case (.right, .right, _):
            // Push tail
            if let next = rightBoundary.rightNeighbour(atLevel: level) {
                return range.lowerBound..<next.absoluteRange.upperBound
            }

        case (.left, .right, false):
            // Trim right
            if let x = rightBoundary.leftNeighbour(atLevel: level)?
                .absoluteRange.upperBound,
                x >= range.lowerBound
            {
                return range.lowerBound..<x
            }
        case (.left, .right, true):
            // Trim tail in a constituent
            if let x = rightBoundary.children.dropLast(1).last?
                .absoluteRange.upperBound,
                x >= range.lowerBound
            {
                return range.lowerBound..<x
            }

        case (.right, .left, false):
            // Trim left
            if let x = leftBoundary.rightNeighbour(atLevel: level)?
                .absoluteRange.lowerBound,
                x <= range.upperBound
            {
                return x..<range.upperBound
            }
        case (.right, .left, true):
            // Trim head in a constituent
            if let x = leftBoundary.children.dropFirst(1).first?
                .absoluteRange.lowerBound,
                x <= range.upperBound
            {
                return x..<range.upperBound
            }

        }
        return nil

    }

    // The current selection with whitespace trimmed off
    func trimmedSelection() -> Range<Int> {
        guard
            let range = Range(self.selectedRange()),
            let string = self.textStorage?.string,
            let stringRange = Range(NSRange(range), in: string)
        else { return 0..<0 }

        let substring = string[stringRange]

        var trimLeft = 0
        var trimRight = 0

        let pass: (Character) -> Bool = { $0.isWhitespace || $0.isNewline }
        while substring.dropFirst(trimLeft).first.map(pass) ?? false { trimLeft += 1 }
        while substring.dropLast(trimRight).last.map(pass) ?? false { trimRight += 1 }

        let start = range.lowerBound + trimLeft
        let end = range.upperBound - trimRight

        return start..<max(start, end)

    }
}
