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

}

extension Constituent: CustomStringConvertible {
    public var description: String {
        "(\(offset) \(length) \(value ?? "?") \(self.children.map { $0.description }.joined(separator: " ")))"
    }
}
