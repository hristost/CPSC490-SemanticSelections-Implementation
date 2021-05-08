import Foundation

extension Range {
    func contains(_ range: Range<Self.Bound>) -> Bool {
        range.clamped(to: self) == range
    }
}
extension Range where Bound: AdditiveArithmetic {
    func offset(by offset: Self.Bound) -> Range<Self.Bound> {
        (self.lowerBound + offset)..<(self.upperBound + offset)
    }
}

extension Constituent {
    /// Find a child constituent that containing a given range and located at a certain level
    /// - Parameters:
    ///     - range: range of characters that the constituent should contain
    ///     - level:
    public func findChild(containing range: Range<Int>, at level: Int) -> (
        child: Constituent, offset: Int
    )? {
        guard (0..<self.length).contains(range) else { return nil }
        if level > 0 {
            for child in children {
                let lowerLevel = children.count > 1 ? level - 1 : level
                if let (grandChild, grandOffset) = child.findChild(
                    containing: range.offset(by: -child.offset),
                    at: lowerLevel)
                {
                    return (grandChild, grandOffset + Int(child.offset))
                }
            }
        }
        return (self, 0)
    }

    /// Find the smallest constituent that fully contains the given range, relative to the parent
    /// - Parameter range: tha range in the parent constituent
    public func descendant(containing range: Range<Int>) -> Constituent? {
        let range = range.offset(by: -self.offset)
        guard (0..<self.length).contains(range) else { return nil }
        for child in children {
            if let grandChild = child.descendant(containing: range) {
                return grandChild
            }
        }
        return self
    }

    enum Direction { case left, right }
    func neighbour(direction: Direction) -> Constituent? {
        guard let parent = self.parent else { return nil }
        let idx = self.index + (direction == .right ? 1 : -1)
        if parent.children.indices.contains(idx) {
            return parent.children[idx]
        } else {
            return parent.neighbour(direction: direction)
        }
    }

    func slide(to level: Int, on side: Direction) -> Constituent {
        func child(node: Constituent) -> Constituent? {
            side == .left ? node.children.first : node.children.last
        }

        var node = self
        while node.level < level,
            let child = side == .left ? node.children.first : node.children.last
        {
            node = child
        }
        return node

    }

    public func leftNeighbour() -> Constituent? {
        return neighbour(direction: .left)?.slide(to: self.level, on: .right)
    }
    public func rightNeighbour() -> Constituent? {
        return neighbour(direction: .right)?.slide(to: self.level, on: .left)
    }
}
