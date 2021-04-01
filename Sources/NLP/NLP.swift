import SwiftCoreNLP

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

    /// Make a constituent tree using a parse tree from CoreNLP
    /// - Parameters:
    ///     - parse: parse tree from CoreNLP
    ///     - tokens: a list of tokens for the sentence containing the constituent tree
    ///     - tokenIdx: index of first token in `tokens` that has not been included in a constituent
    ///     - start: index in the document string where this constituent begins
    init(
        parse: Edu_Stanford_Nlp_Pipeline_ParseTree,
        tokens: [Edu_Stanford_Nlp_Pipeline_Token],
        tokenIdx: inout Int,
        start: inout UInt32,
        end: inout UInt32
    ) {
        parent = nil
        if parse.child.isEmpty {
            // This node has no children, therefore it is a leaf node
            let token = tokens[tokenIdx]
            tokenIdx += 1

            start = min(start, token.beginChar)
            end = max(end, token.endChar)

            self.offset = token.beginChar - start
            self.length = token.endChar - token.beginChar
            self.children = []
            self.value = token.word

        } else {

            var _start: UInt32 = .max
            var _end: UInt32 = .min

            self.children = parse.child.map {
                Constituent(
                    parse: $0, tokens: tokens, tokenIdx: &tokenIdx, start: &_start, end: &_end)

            }
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

    /// Make a constituent tree using a parse tree from CoreNLP
    /// - Parameters:
    ///     - parse: parse tree from CoreNLP
    ///     - tokens: a list of tokens for the sentence containing the constituent tree
    ///     - tokenIdx: index of first token in `tokens` that has not been included in a constituent
    ///     - start: index in the document string where this constituent begins
    convenience init(
        sentence: Edu_Stanford_Nlp_Pipeline_Sentence,
        start: inout UInt32,
        end: inout UInt32
    ) {
        var tokenIdx = 0
        var _start: UInt32 = .max
        var _end: UInt32 = .min
        self.init(
            parse: sentence.parseTree, tokens: sentence.token, tokenIdx: &tokenIdx,
            start:
                &_start, end: &_end)

        start = min(start, _start)
        end = max(end, _end)
        self.offset = _start - start
        self.length = _end - _start
    }
    /// Make a constituent tree using a parse tree from CoreNLP
    /// - Parameters:
    ///     - parse: parse tree from CoreNLP
    ///     - tokens: a list of tokens for the sentence containing the constituent tree
    ///     - tokenIdx: index of first token in `tokens` that has not been included in a constituent
    ///     - start: index in the document string where this constituent begins
    public init(
        document: Edu_Stanford_Nlp_Pipeline_Document
    ) {
        var _start: UInt32 = .max
        var _end: UInt32 = .min
        self.children = document.sentence.map {
            Constituent(sentence: $0, start: &_start, end: &_end)
        }
        self.offset = children.isEmpty ? 0 : _start
        self.length = children.isEmpty ? 0 : _end - _start
    }
}


extension Constituent: CustomStringConvertible {
    public var description: String {
        if let value = value {
            return "(\(offset) \(length) \(value))"
        } else {
            return "(\(offset) \(length) \(self.children.map { $0.description }.joined(separator: " ")))"
        }
    }
}
