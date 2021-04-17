import Foundation
import PythonKit

public class Constituent {
    /// Parent of the constituent. If null, this is the ROOT
    public weak var parent: Constituent?
    /// There character offset where this constituent begins in its parent
    public var offset: UInt32
    /// Length of the constituent in characters
    public var length: UInt32
    /// Children constituents
    public var children: [Constituent]

    public var value: String? = nil

    /// Make a constituent tree using a nltk parse tree
    /// - Parameters:
    ///     - parse: nltk.Tree python object
    ///     - tokens: a list of tokens for the sentence containing the constituent tree
    ///     - tokenIdx: index of first token in `tokens` that has not been included in a constituent
    ///     - start: index in the document string where this constituent begins
    init(
        parse: PythonObject,
        tokens: [(start: UInt32, end: UInt32)],
        tokenIdx: inout Int,
        start: inout UInt32,
        end: inout UInt32
    ) {
        parent = nil
        let children: [PythonObject] = .init(parse.children)
        if children.isEmpty {
            // This node has no children, therefore it is a leaf node
            let token = tokens[tokenIdx]
            tokenIdx += 1

            start = min(start, token.start)
            end = max(end, token.end)

            self.offset = token.start - start
            self.length = token.end - token.start
            self.children = []
            self.value = String(parse.label)

        } else {
            var _start: UInt32 = .max
            var _end: UInt32 = .min

            self.children = children.map {
                return Constituent(
                    parse: $0, tokens: tokens, tokenIdx: &tokenIdx, start: &_start, end: &_end)

            }
            self.value = String(parse.label)

            // Transform unary trees
            if self.children.count == 1 {
                if self.children[0].children.isEmpty {
                    self.value = self.children[0].value
                }
                self.children = self.children[0].children

            }

            start = min(start, _start)
            end = max(end, _end)
            self.offset = _start - start
            self.length = _end - _start

        }
        self.children.forEach { $0.parent = self }
    }
    convenience init(
        sentence: (parseTree: PythonObject, tokens: [(UInt32, UInt32)]),
        start: inout UInt32,
        end: inout UInt32
    ) {
        var tokenIdx = 0
        var _start: UInt32 = .max
        var _end: UInt32 = .min
        self.init(
            parse: sentence.parseTree, tokens: sentence.tokens, tokenIdx: &tokenIdx,
            start:
                &_start, end: &_end)

        start = min(start, _start)
        end = max(end, _end)
        self.offset = _start - start
        self.length = _end - _start
    }
    /// Make a constituent tree using a nltk tree
    /// - Parameters:
    ///     - parse: nltk.Tree python object
    ///     - tokens: a list of tokens for the sentence containing the constituent tree
    ///     - tokenIdx: index of first token in `tokens` that has not been included in a constituent
    ///     - start: index in the document string where this constituent begins
    public init(
        sentences: [(parseTree: PythonObject, tokens: [(UInt32, UInt32)])]
    ) {
        var _start: UInt32 = .max
        var _end: UInt32 = .min
        self.children = sentences.map {
            print("Mapping sentence with \($0.tokens.count) tokens")
            let c = Constituent(sentence: $0, start: &_start, end: &_end)
            print("Done")
            return c
        }
        self.offset = children.isEmpty ? 0 : _start
        self.length = children.isEmpty ? 0 : _end - _start
        print("Conversion done")
        print(self)
    }
}

extension Constituent: CustomStringConvertible {
    public var description: String {
        "(\(offset) \(length) \(value ?? "?") \(self.children.map { $0.description }.joined(separator: " ")))"
    }
}
