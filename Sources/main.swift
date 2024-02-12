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

        @Option(help: "Swift source code to execute.")
        var source: String?

        @Option(name: .shortAndLong, help: "Path to the Swift file to execute.")
        var file: String?

        func run() throws {
            if let filePath = file {
                do {
                    print("Executing Swift code from file: \(filePath)")
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
            print("Debug - Received code for execution: \(code)")
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
                try process.run()

                executionQueue.async {
                    process.waitUntilExit()
                    processCompletion.signal()
                }

                if processCompletion.wait(timeout: timeout) == .timedOut {
                    process.terminate()
                    print("Debug - Execution timed out")
                    throw ExecutionError.timeout
                }

                if #available(macOS 10.15.4, *) {
                    let executionResult = ProcessExecutionResult(
                        output: try outputPipe.fileHandleForReading.readToEnd().map { String(data: $0, encoding: .utf8)! },
                        error: try errorPipe.fileHandleForReading.readToEnd().map { String(data: $0, encoding: .utf8)! },
                        status: Int(process.terminationStatus)
                    )

                    handleExecutionResult(executionResult)
                }

                // Clean up the temporary file
                try FileManager.default.removeItem(at: tempFileURL)
            } catch {
                fatalError("Failed to execute Swift code: \(error)")
            }
        }

        private func handleExecutionResult(_ executionResult: ProcessExecutionResult) {
            if let output = executionResult.output {
                print("Execution Output: \(output)")
            }
            if let errorOutput = executionResult.error {
                let structuredErrors = parseCompilerMessages(errorOutput)
                print("Compiler Messages: \(structuredErrors)")
            }
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

public struct ProcessExecutionResult: Hashable, Equatable {
    var output: String?
    var error: String?
    var status: Int
}

SwiftSourceEval.Run.main()

#endif
