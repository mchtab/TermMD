import SwiftUI
import SwiftTerm
import AppKit

struct TerminalPaneView: NSViewRepresentable {
    @EnvironmentObject var terminalController: TerminalController
    @EnvironmentObject var appSettings: AppSettings

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        terminalController.terminalView = tv

        let shell = appSettings.shellPath
        let shellName = (shell as NSString).lastPathComponent

        // Gather environment variables
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        let envArray = env.map { "\($0.key)=\($0.value)" }

        tv.startProcess(executable: shell, args: [], environment: envArray, execName: "-\(shellName)")

        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Terminal view manages itself
    }
}
