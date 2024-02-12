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
        var source: String

        @Option(name: .shortAndLong, help: "Path to the Swift file to execute.")
        var file: String

        func run() throws {
            print("Executing Swift code from file: \(file)")
            // Placeholder for code execution logic
        }
    }
}

SwiftSourceEval.Run.main()
