import Foundation

public class Constituent {
    /// Parent of the constituent. If null, this is the ROOT
    public weak var parent: Constituent?
    /// How many ancestors the constituent has. If 0, this is the ROOT
    public var level: Int
    /// The index of the constituent in the ancestor (if any)
    public var index: Int
    /// There character offset where this constituent begins in its parent
    public var offset: Int
    /// Length of the constituent in characters
    public var length: Int

    /// Children constituents
    public var children: [Constituent]

    public var value: String? = nil

    /// Last children constituent that was selected when expanding or refining a selection
    public var lastFocus: Constituent?

    /// A hash value for the string from which this constituent was made
    public var hash: Int?

    /// Range in the parent constituent
    public var range: Range<Int> {
        (0..<self.length).offset(by: self.offset)
    }

    /// Range in document
    public var absoluteRange: Range<Int> {
        self.range.offset(by: self.parent?.absoluteRange.lowerBound ?? 0)
    }

    public init(
        value: String?, level: Int, index: Int, offset: Int, length: Int,
        children:
            [Constituent]
    ) {
        self.level = level
        self.index = index
        self.offset = offset
        self.length = length
        self.children = children
        self.value = value
    }

    /// How many levels of descendants the constituent has
    public var height: Int {
        children.map(\.height).reduce(0, max)
    }
}

extension Constituent: CustomStringConvertible {
    public var description: String {
        "(\(offset) \(length) L\(level) \(value ?? "?") \(self.children.map { $0.description }.joined(separator: " ")))"
    }
}

extension Constituent: Equatable {
    public static func == (lhs: Constituent, rhs: Constituent) -> Bool {
        return lhs.absoluteRange == rhs.absoluteRange
    }
}
