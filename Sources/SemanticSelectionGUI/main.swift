import AppKit
import ArgumentParser
import SwiftCoreNLP


struct GUI: ParsableCommand {

    @Option(name: .shortAndLong, help: "Endpoint for a CoreNLP Server")
    var server: String = "http://localhost:9000/"

    enum StartError: Error {
        case noServer
    }

    mutating func run() throws {
        guard let server = CoreNLPServer(url: self.server) else {
            throw StartError.noServer
        }
        LanguageServer.shared = server

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class LanguageServer {
    static var shared: CoreNLPServer!
}



GUI.main()
