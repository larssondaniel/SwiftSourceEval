//
//  SwiftSourceEvalTests.swift
//
//
//  Created by Daniel Larsson on 2/12/24.
//

#if os(macOS)

import ArgumentParser
import Foundation

struct ExecutionConfig {
    static let executionTimeout: TimeInterval = 5 // Timeout in seconds
}

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
                    waitForExecutionToComplete(swiftCode: swiftCode)
                } catch {
                    fatalError("Failed to read file at \(filePath): \(error)")
                }
            } else if let code = source {
                waitForExecutionToComplete(swiftCode: code)
            } else {
                fatalError("No Swift source code or file path provided")
            }
        }

        private func waitForExecutionToComplete(swiftCode: String) {
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()

            let executionQueue = DispatchQueue(label: "swiftExecutionQueue")
            executionQueue.async(group: dispatchGroup) {
                self.executeSwiftCode(swiftCode)
                dispatchGroup.leave()
            }

            dispatchGroup.wait()
            print("All asyncronous execution tasks have completed.")
        }

        private func executeSwiftCode(_ code: String) {
            let tempFilePath = NSTemporaryDirectory() + "temp.swift"
            let tempFileURL = URL(fileURLWithPath: tempFilePath)

            do {
                try code.write(to: tempFileURL, atomically: true, encoding: .utf8)
                let process = Process()
                // Run process in sandbox
                if #available(macOS 13.0, *) {
                    process.executableURL = URL(filePath: "/usr/bin/sandbox-exec")
                }
                process.arguments = ["-f", "./swiftexec.sb", "/usr/bin/swift", tempFilePath]
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.standardOutput = outputPipe
                process.standardError = errorPipe
                let timeout = DispatchTime.now() + ExecutionConfig.executionTimeout
                let executionQueue = DispatchQueue(label: "processExecutionQueue")
                let processCompletion = DispatchSemaphore(value: 0)
                process.launch()

                executionQueue.async {
                    process.waitUntilExit()
                    processCompletion.signal()
                }

                if processCompletion.wait(timeout: timeout) == .timedOut {
                    process.terminate()
                    throw ExecutionError.timeout
                }

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

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
                let structuredErrors = parseCompilerMessages(errorOutput)
                print("Compiler Messages: \(structuredErrors)")
                // TODO: Parse errorOutput to structure it as needed
            }
            // Future updates may include more detailed parsing and structuring of error messages
            // and warnings for a clearer output.
        }

        private func parseCompilerMessages(_ messages: String) -> [CompilerMessage] {
            let lines = messages.split(separator: "\n")
            var compilerMessages: [CompilerMessage] = []

            for line in lines {
                // Simple parsing logic to differentiate errors from warnings
                // This is a placeholder and should be replaced with more robust parsing
                if line.contains("error: ") {
                    compilerMessages.append(CompilerMessage(type: .error, message: String(line)))
                } else if line.contains("warning: ") {
                    compilerMessages.append(CompilerMessage(type: .warning, message: String(line)))
                }
            }

            return compilerMessages
        }
    }
}

struct CompilerMessage {
    enum MessageType {
        case error, warning
    }

    let type: MessageType
    let message: String
}

enum ExecutionError: Error {
    case timeout
}

SwiftSourceEval.Run.main()

#endif
