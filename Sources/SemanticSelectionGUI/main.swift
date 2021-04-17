import AppKit
import ArgumentParser
import NLP
import PythonKit

import func Darwin.fputs
import var Darwin.stderr

struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) {
        fputs(string, stderr)
    }
}

var standardError = StderrOutputStream()
struct GUI: ParsableCommand {

    @Option(name: .shortAndLong, help: "Endpoint for a CoreNLP Server")
    var server: String = "http://localhost:9000/"

    enum StartError: Error {
        case noServer
    }

    mutating func run() throws {
        do {
            Parser.shared = try Parser()
        } catch let error {

            print(
                """
                Could not interface with parser. Make sure that:
                - supar is installed:
                    python3 -m pip install -U supar
                - The bridge script can run:
                    python3 ./Sources/NLP/Resources/supar_bridge.py
                  (should output "Parser loaded successfully")
                - The swift program interfaces with the correct version of python.
                    PYTHON_LIBRARY=$(which python3) swift run
                """, to: &standardError)
            if let pyVersion = try? String(Python.attemptImport("sys").version) {
                print(
                    """
                      You are currently using:
                        \(pyVersion.split(separator: "\n").joined(separator: "\n    "))
                    """, to: &standardError)
            }
            print(
                """

                ===

                \(error)
                """, to: &standardError)
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

GUI.main()
