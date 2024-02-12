//
//  SwiftSourceEvalTests.swift
//
//
//  Created by Daniel Larsson on 2/12/24.
//

import ArgumentParser
import Foundation

struct SwiftSourceEval: ParsableCommand {

    static let configuration = CommandConfiguration(abstract: "A utility for executing Swift code.", subcommands: [Run.self], defaultSubcommand: Run.self)
}

extension SwiftSourceEval {
    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run Swift source code.")

        @Argument(help: "Swift source code to execute.")
        var source: String?

        @Option(name: .shortAndLong, help: "Path to the Swift file to execute.")
        var file: String?

        func run() throws {
            print("Executing Swift code from file: \(file ?? "no file provided")")
            // Placeholder for code execution logic
            if let filePath = file {
                do {
                    let fileURL = URL(fileURLWithPath: filePath)
                    let swiftCode = try String(contentsOf: fileURL, encoding: .utf8)
                    executeSwiftCode(swiftCode)
                } catch {
                    fatalError("Failed to read file at \(filePath): \(error)")
                }
            } else if let code = source {
                executeSwiftCode(code)
            } else {
                fatalError("No Swift source code or file path provided")
            }
        }

        private func executeSwiftCode(_ code: String) {
            let tempFilePath = NSTemporaryDirectory() + "temp.swift"
            let tempFileURL = URL(fileURLWithPath: tempFilePath)

            do {
                try code.write(to: tempFileURL, atomically: true, encoding: .utf8)
                let process = Process()
                process.launchPath = "/usr/bin/swift"
                process.arguments = [tempFilePath]
                process.launch()
                process.waitUntilExit()
            } catch {
                fatalError("Failed to execute Swift code:\(error)")
            }
        }
    }
}

SwiftSourceEval.Run.main()
