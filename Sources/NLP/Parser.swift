import Foundation
import PythonCodable
import PythonKit

public class Parser {
    public static var shared: Parser! = nil
    internal var nlp: PythonObject

    public init() throws {
        let bridgeModuleName = "supar_bridge"
        guard
            let moduleFolder: URL = Bundle.module.url(
                forResource: bridgeModuleName,
                withExtension: "py"
            )?.deletingLastPathComponent()
        else { throw SuParError.noPythonScript }

        let sys = try Python.attemptImport("sys")
        sys.path.append(moduleFolder.path)

        self.nlp = try Python.attemptImport(bridgeModuleName)
    }

    public enum SuParError: Error {
        case noModule
        case noPythonScript
        case pythonConversionError
    }

    public func parse(_ text: String) throws -> Constituent {
        let parse = nlp.parse(text)
        let sents = try parse.map {
            parse -> (PythonTree, [PythonToken]) in
            let (ptTree, ptTokens) = (parse[0], parse[1])
            let tokens = try ptTokens.map {
                try PythonDecoder.decode(PythonToken.self, from: $0)
            }
            let tree = try PythonDecoder.decode(PythonTree.self, from: ptTree)
            return (tree, tokens)
        }

        return Constituent(sentences: sents)
    }
}

// MARK: Structures for decoding Python objects
private struct PythonTree: Decodable {
    var label: String
    var children: [PythonTree]
}

private struct PythonToken: Decodable {
    var start: Int
    var end: Int
}

// MARK: Initialise Constituent using Python trees
private extension Constituent {
    /// Make a constituent tree using a list of sentence parses
    /// - Parameters:
    ///     - sentences: array of parse trees and tokens for each sentence
    convenience init(
        sentences: [(parseTree: PythonTree, tokens: [PythonToken])]
    ) {
        var _start: Int = .max
        var _end: Int = .min
        let children = sentences.enumerated().map { (idx, sent) in
            Constituent(sentence: sent, index: idx, start: &_start, end: &_end)
        }
        self.init(
            value: "DOC",
            level: 0,
            index: 0,
            offset: children.isEmpty ? 0 : _start,
            length: children.isEmpty ? 0 : _end - _start,
            children: children)
    }

    /// Make a constituent tree using a nltk parse tree
    /// - Parameters:
    ///     - parse: nltk.Tree python object
    ///     - level: how many ancestors have been parsed
    ///     - tokens: a list of tokens for the sentence containing the constituent tree
    ///     - tokenIdx: index of first token in `tokens` that has not been included in a constituent
    ///     - start: index in the document string where this constituent begins
    convenience init(
        parse: PythonTree,
        level: Int = 0,
        index: Int,
        tokens: [PythonToken],
        tokenIdx: inout Int,
        start: inout Int,
        end: inout Int
    ) {
        if parse.children.isEmpty {
            // This node has no children, therefore it is a leaf node
            let token = tokens[tokenIdx]
            tokenIdx += 1

            start = min(start, token.start)
            end = max(end, token.end)

            self.init(
                value: parse.label,
                level: level,
                index: index,
                offset: token.start - start,
                length: token.end - token.start,
                children: [])

        } else {
            var _start: Int = .max
            var _end: Int = .min

            var children = parse.children.enumerated().map { (idx, tree) in
                Constituent(
                    parse: tree, level: level + 1, index: idx,
                    tokens: tokens, tokenIdx: &tokenIdx,
                    start: &_start, end: &_end)

            }
            var value = parse.label

            // Transform unary trees
            if children.count == 1 {
                if children[0].children.isEmpty {
                    value = children[0].value ?? value
                }
                children = children[0].children
            }

            start = min(start, _start)
            end = max(end, _end)

            self.init(
                value: value,
                level: level,
                index: index,
                offset: _start - start,
                length: _end - _start,
                children: children)
            self.children.forEach { $0.parent = self }
        }
    }
    convenience init(
        sentence: (parseTree: PythonTree, tokens: [PythonToken]),
        index: Int,
        start: inout Int,
        end: inout Int
    ) {
        var tokenIdx = 0
        var _start: Int = .max
        var _end: Int = .min
        self.init(
            parse: sentence.parseTree, level: 1, index: index, tokens: sentence.tokens,
            tokenIdx: &tokenIdx,
            start:
                &_start, end: &_end)

        start = min(start, _start)
        end = max(end, _end)
        self.offset = _start - start
        self.length = _end - _start
    }
}
