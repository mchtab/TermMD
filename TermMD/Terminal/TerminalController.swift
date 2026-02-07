import Foundation
import SwiftTerm
import AppKit

/// Concrete implementation of TerminalControlling that manages a LocalProcessTerminalView.
class TerminalController: ObservableObject, TerminalControlling {
    var terminalView: LocalProcessTerminalView?

    func send(_ text: String) {
        guard let tv = terminalView else { return }
        let bytes = Array(text.utf8)
        tv.process.send(data: bytes[bytes.startIndex...])
    }

    func runClaude(in directory: URL, command: String, filePath: String? = nil) {
        var cmd = "cd \"\(directory.path)\" && \(command)"
        if let path = filePath {
            // Tell Claude which file we're working on
            cmd += " \"\(path)\""
        }
        cmd += "\n"
        send(cmd)
    }

    func injectPrompt(_ prompt: String) {
        send(prompt + "\n")
    }

    func focus() {
        guard let tv = terminalView else { return }
        tv.window?.makeFirstResponder(tv)
    }
}
