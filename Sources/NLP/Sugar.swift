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
