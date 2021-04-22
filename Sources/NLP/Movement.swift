import Foundation

public extension Constituent {
    /// Find a child constituent that containing a given range and located at a certain level
    /// - Parameters:
    ///     - range: range of characters that the constituent should contain
    ///     - level:
    func findChild(containing range: Range<Int>, at level: Int) -> (
        child: Constituent, offset: Int,
        depth: Int
    )? {
        if range.startIndex >= 0 && range.endIndex <= self.length {
            if level > 0 {
                for child in children {
                    let offset = child.offset
                    let range = (range.lowerBound - offset)..<(range.upperBound - offset)
                    let lowerLevel = children.count > 1 ? level - 1 : level
                    if let (grandChild, grandOffset, grandDepth) = child.findChild(
                        containing: range,
                        at:
                            lowerLevel)
                    {
                        return (grandChild, grandOffset + Int(child.offset), 1 + grandDepth)
                    }
                }
            }
            return (self, 0, 0)
        } else {
            return nil
        }
    }

    func leftNeighbour() -> Constituent? {
        return nil
    }
    func rightNeighbour() -> Constituent? {
        return nil
    }
}
