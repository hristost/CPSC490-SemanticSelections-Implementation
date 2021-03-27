import Foundation

public extension Constituent {
    var depth: Int {
        (self.parent?.depth ?? -1) + 1

    }
    func findChild(containing range: NSRange, at level: Int) -> (child: Constituent, offset: Int,
depth: Int)? {
        if range.location >= 0 && range.length + range.location <= Int(self.length) {
            if level > 0 {
                for child in children {
                    var range = range
                    range.location -= Int(child.offset)
                    let lowerLevel = children.count > 1 ? level - 1 : level
                    if let (grandChild, grandOffset, grandDepth) = child.findChild(containing: range, at:
lowerLevel) {
                        return (grandChild, grandOffset + Int(child.offset), 1 + grandDepth)
                    }
                }
            }
            return (self, 0, 0)
        } else {
            return nil
        }
    }
}
