import Foundation
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
            parse -> (PythonObject, [(UInt32, UInt32)]) in
            let parseTree = parse[0]
            let tokens: [(start: UInt32, end: UInt32)] = try parse[1].map {
                guard let start = UInt32($0[0]), let end = UInt32($0[1]) else {
                    throw SuParError.pythonConversionError

                }
                return (start, end)
            }
            return (parseTree: parseTree, tokens: tokens)
        }

        return Constituent(sentences: sents)
    }
}
