import AppKit
import NLP
import Backend

// MARK: Colour schemes
let colorSchemes: [String: SemanticTextView.Highlight] = [
    "Orange": .linear(
        NSColor.systemOrange,
        NSColor.systemBlue
            .blended(withFraction: 0.6, of: .labelColor)!
            .withAlphaComponent(0.6)
    ),
    "Pink": .linear(
        NSColor.systemPink,
        NSColor.systemBlue
            .blended(withFraction: 0.2, of: .labelColor)!
            .withAlphaComponent(0.8)
    ),
    "Pink - Blue - Grey": .tricolor(
        NSColor.systemPink,
        NSColor.systemBlue
            .blended(withFraction: 0.2, of: .labelColor)!
            .withAlphaComponent(0.7),
        NSColor.systemBlue
            .blended(withFraction: 0.8, of: .labelColor)!
            .withAlphaComponent(0.6)
    )
]

// MARK: Highlighting
extension Range {
    func contains(_ range: Range<Self.Bound>) -> Bool {
        range.clamped(to: self) == range
    }
}
let fadedTextColor = NSColor.labelColor.withAlphaComponent(0.4)
let fadedParagraphColor = NSColor.labelColor.withAlphaComponent(0.6)

extension SemanticTextView {
    enum Highlight {
        case none
        case linear(NSColor, NSColor)
        case tricolor(NSColor, NSColor, NSColor)
    }
    /// Apply semantic highlighting
    func highlight() {
        guard let parse = self.parse else { return }
        guard let text = self.textStorage else { return }

        let selection = self.selectedRange()
        let start = NSRange(location: selection.lowerBound, length: 0)
        let end = NSRange(location: selection.upperBound, length: 0)

        let sentencesRange = NSUnionRange(
            self.selectionRange(forProposedRange: start, granularity: .selectByParagraph),
            self.selectionRange(forProposedRange: end, granularity: .selectByParagraph)
        )

        let paragraphGranularity = NSSelectionGranularity(rawValue: 4)!
        let paragraphsRange = NSUnionRange(
            self.selectionRange(forProposedRange: start, granularity: paragraphGranularity),
            self.selectionRange(forProposedRange: end, granularity: paragraphGranularity)
        )

        let totalLength = self.attributedString().length
        guard
            totalLength > 0,
            sentencesRange.lowerBound <= totalLength,
            sentencesRange.upperBound <= totalLength
        else { return }

        text.addAttributes([.underlineStyle: 0], range: NSRange(0..<text.length))
        text.addAttributes([.foregroundColor: fadedTextColor], range: NSRange(0..<text.length))
        text.addAttributes([.foregroundColor: fadedParagraphColor], range: paragraphsRange)

        for sent in parse.children
        where Range(sentencesRange)?.contains(sent.absoluteRange) ?? false {
            highlight(tree: sent, levels: sent.enumerateLevels().sorted())
        }

        if let nextConstituent = self.constituentContainingSelection() {
            let range = nextConstituent.absoluteRange
            text.addAttributes(
                [.underlineStyle: NSUnderlineStyle.single.rawValue],
                range: NSRange(range))
        }

    }

    /// The foreground colour for a word with the given embedding level
    /// - Parameter depth: a value between 0 and 1, where 0 is most shallow, and 1 most deep
    func color(forLevel depth: CGFloat) -> NSColor {
        let easeIn: (CGFloat) -> CGFloat = { pow($0, 1.2) }
        let easeOut: (CGFloat) -> CGFloat = { 1 - pow(1 - $0, 1.2) }

        switch self.colors {
        case .tricolor(let a, let b, let c):
            switch depth {
            case 0..<1 / 2:
                return a.blended(withFraction: easeOut(depth * 2), of: b) ?? a
            default:
                return b.blended(withFraction: easeIn((depth - 0.5) * 2), of: c) ?? b
            }

        case .linear(let a, let b):
            return a.blended(withFraction: depth, of: b) ?? a

        case .none:
            return .labelColor
        }
    }

    func highlight(tree: Constituent, levels: [Int], offset: Int = 0) {
        guard let text = self.textStorage else { return }
        if tree.children.isEmpty {
            let start = tree.offset
            let length = tree.length
            let range = NSMakeRange(Int(start) + offset, Int(length))
            let level = levels.firstIndex(of: tree.level) ?? 0
            let maxLevels = Parser.shared!.language == .english ? 6 : 8
            let alpha =
                levels.count > 1
                ? (CGFloat(level) / CGFloat(min(levels.count - 1, maxLevels))).clamped(to: 0..<1)
                : 0.5
            let color = self.color(forLevel: alpha)
            let totalLength = self.attributedString().length
            if totalLength > 0 {
                guard range.lowerBound <= totalLength,
                    range.upperBound <= totalLength
                else { return }
            }
            text.addAttribute(.foregroundColor, value: color, range: range)
        } else {
            tree.children.forEach {
                highlight(tree: $0, levels: levels, offset: offset + Int(tree.offset))
            }
        }
    }

}

extension Constituent {
    /// The levels of all leaf nodes
    fileprivate func enumerateLevels() -> Set<Int> {
        let isLeaf = children.isEmpty && !".,!?".contains(self.value ?? "")
        return
            self.children
            .map { $0.enumerateLevels() }
            .reduce(isLeaf ? [self.level] : []) { $0.union($1) }
    }
}
