import AppKit

extension SemanticTextView: NSTextViewDelegate {
    func textView(
        _ textView: NSTextView,
        willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange,
        toCharacterRange newSelectedCharRange: NSRange
    ) -> NSRange {
        // Update the `selectionDirection` property whenever the selection is changed
        //
        // Source: https://stackoverflow.com/a/23667851

        if newSelectedCharRange.length != 0 {

            var anchorStart = self.lastAnchorPoint.lowerBound
            let selectionStart = newSelectedCharRange.location
            let selectionLength = newSelectedCharRange.length
            // If mouse selects left, and then a user arrows right, or the opposite, anchor point
            // flips.
            let difference = anchorStart - selectionStart
            if difference > 0 && difference != selectionLength {
                if oldSelectedCharRange.location == newSelectedCharRange.location {
                    // We were selecting left via mouse, but now we are selecting to the right via
                    // arrows
                    anchorStart = selectionStart
                } else {
                    // We were selecting right via mouse, but now we are selecting to the left via
                    // arrows
                    anchorStart = selectionStart + selectionLength
                }
                self.lastAnchorPoint = anchorStart..<anchorStart
            }
            self.selectionDirection = (anchorStart == selectionStart) ? .right : .left
        }

        return newSelectedCharRange
    }

}
