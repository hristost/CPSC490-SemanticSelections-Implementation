import AppKit
import NLP

extension Range {
    func contains(_ range: Range<Self.Bound>) -> Bool {
        range.clamped(to: self) == range
    }
}
let fadedTextColor = NSColor.labelColor.withAlphaComponent(0.4)
let fadedParagraphColor = NSColor.labelColor.withAlphaComponent(0.6)
let deepColor = NSColor.systemBlue.blended(withFraction: 0.7, of: .labelColor)!.withAlphaComponent(0.6)
let shallowColor = NSColor.systemOrange

extension SemanticTextView {
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
            print(sent.enumerateLevels().sorted())
            highlight(tree: sent, levels: sent.enumerateLevels().sorted())
        }

        if let nextConstituent = self.constituentContainingSelection() {
            let range = nextConstituent.absoluteRange
            text.addAttributes(
                [.underlineStyle: NSUnderlineStyle.single.rawValue],
                range: NSRange(range))
        }

    }

    func highlight(tree: Constituent, levels: [Int], offset: Int = 0) {
        guard let text = self.textStorage else { return }
        if tree.children.isEmpty {
            let start = tree.offset
            let length = tree.length
            let range = NSMakeRange(Int(start) + offset, Int(length))
            let level = levels.firstIndex(of: tree.level) ?? 0
            let alpha =
                levels.count > 1
                ? (CGFloat(level) / CGFloat(min(levels.count - 1, 6))).clamped(to: 0..<1)
                : 0.5
            let color = shallowColor.blended(withFraction: alpha, of: deepColor)
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
