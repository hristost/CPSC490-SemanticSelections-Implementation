import Foundation

extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
extension CGFloat {
    func clamped(to range: Range<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Optional {
    func makeNil(if cond: Bool) -> Wrapped? {
        cond ? nil : self
    }
}
