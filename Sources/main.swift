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

            var output = ""
            var errorOutput = ""

            do {
                try code.write(to: tempFileURL, atomically: true, encoding: .utf8)
                let process = Process()
                process.launchPath = "/usr/bin/sandbox-exec"
                // Run process with sandbox profile
                process.arguments = ["-f", "./swiftexec.sb", "/usr/bin/swift", tempFilePath]
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                process.launch()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                output = String(data: outputData, encoding: .utf8) ?? ""
                errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                handleExecutionOutput(output, errorOutput: errorOutput)

                // Clean up the temporary file
                try FileManager.default.removeItem(at: tempFileURL)
            } catch {
                fatalError("Failed to execute Swift code:\(error)")
            }
        }

        private func handleExecutionOutput(_ output: String, errorOutput: String) {
            if !output.isEmpty {
                print("Execution Output: \(output)")
            }
            if !errorOutput.isEmpty {
                print("Error Output: \(errorOutput)")
                // TODO: Parse errorOutput to structure it as needed
            }
            // Future updates may include more detailed parsing and structuring of error messages
            // and warnings for a clearer output.
        }
    }
}

SwiftSourceEval.Run.main()
