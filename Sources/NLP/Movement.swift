import Foundation

public extension Constituent {
    /// Find a child constituent that containing a given range and located at a certain level
    /// - Parameters:
    ///     - range: range of characters that the constituent should contain
    ///     - level:
    func findChild(containing range: Range<Int>, at level: Int) -> (
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
    func descendant(containing range: Range<Int>) -> Constituent? {
        let range = range.offset(by: -self.offset)
        guard (0..<self.length).contains(range) else { return nil }
        for child in children {
            if let grandChild = child.descendant(containing: range) {
                return grandChild
            }
        }
        return self
    }

    /// The neighbouring node on the left, if any
    ///
    /// The returned node is not necessarily a sibling node, but does share an ancestor at some
    /// level
    func leftNeighbour(atLevel level: Int? = nil) -> Constituent? {
        return neighbour(direction: .left)?.slide(to: level ?? self.level, on: .right)
    }

    /// The neighbouring node on the right, if any
    ///
    /// The returned node is not necessarily a sibling node, but does share an ancestor at some
    /// level
    func rightNeighbour(atLevel level: Int? = nil) -> Constituent? {
        return neighbour(direction: .right)?.slide(to: level ?? self.level, on: .left)
    }

    /// An ancestor node which is a top-level sentence.
    func sentenceAncestor() -> Constituent? {
        var node = self
        while node.value != "TOP", let parent = node.parent { node = parent }
        return node.value == "TOP" ? node : nil
    }

    /// Find a non-intersecting pair of children nodes `(left, right)`, such that the left node
    /// has the same start offset as the given range, and the right node shares the same end offset
    ///
    /// - Parameters:
    ///     - range: selection range local to this constituent
    ///
    /// - Returns: `(l, r)` where `l.absoluteRange.lowerBound == self.absoluteRange.lowerBound`
    ///     and `r.absoluteRange.upperBound == self.absoluteRange.upperBound`
    func findBoundaryNodes(for range: Range<Int>) -> (left: Constituent, right: Constituent)? {
        guard
            let left = self.firstChild(where: {
                let span = $0.absoluteRange
                return span.lowerBound == range.lowerBound && span.upperBound <= range.upperBound
            }),
            let right = self.firstChild(where: {
                let span = $0.absoluteRange
                return span.upperBound == range.upperBound && span.lowerBound >= range.lowerBound
            })
        else { return nil }

        return (left, right)
    }
}

private extension Constituent {
    enum Direction { case left, right }

    /// Find a neighbouring node on either side.
    ///
    /// If this node is the first or last in its parent constituent, this function will return the
    /// parent's neighbour which has a higher level
    func neighbour(direction: Direction) -> Constituent? {
        guard let parent = self.parent else { return nil }
        let idx = self.index + (direction == .right ? 1 : -1)
        if parent.children.indices.contains(idx) {
            return parent.children[idx]
        } else {
            return parent.neighbour(direction: direction)
        }
    }

    /// A descendant node at the specified level that has the same start (`side == .left`) or end
    /// (`side == .right`) offset
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

    /// Find the first descendant that satisfies the given condition
    /// - Parameters:
    ///     - isTarget: a condition that the returned node should satisfy
    ///     - ancestorFilter: an optional condition that holds for all ancestors of the target node,
    ///     used to speed up search
    func firstChild(
        where isTarget: (Constituent) -> Bool,
        andWhereAncestor ancestorFilter: (Constituent) -> Bool = { _ in true }
    ) -> Constituent? {
        if let target = children.first(where: isTarget) {
            return target
        }
        for child in children where ancestorFilter(child) {
            if let target = child.firstChild(where: isTarget, andWhereAncestor: ancestorFilter) {
                return target
            }
        }

        return nil
    }

}
