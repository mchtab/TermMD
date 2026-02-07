import Foundation
import Combine

// MARK: - Editor Model

/// Central editor state. One instance shared across the app via @EnvironmentObject.
class EditorModel: ObservableObject {
    @Published var content: String = ""
    @Published var isDirty: Bool = false
    @Published var currentFileURL: URL? = nil
    @Published var selectedText: String = ""
    @Published var selectionLineRange: ClosedRange<Int>? = nil  // 1-based line numbers
    @Published var selectionNSRange: NSRange = NSRange(location: 0, length: 0)
    @Published var conflictBannerVisible: Bool = false

    /// SHA-256 hash of content at last save, used for disk-change detection.
    var lastSavedHash: String = ""
}

// MARK: - Terminal Controller Protocol

/// Interface for the terminal pane. Task 1 provides the concrete implementation.
protocol TerminalControlling: AnyObject {
    /// Write raw text to the PTY as if the user typed it.
    func send(_ text: String)

    /// Start a Claude Code session: sends `cd "<dir>" && <command>\n` to the PTY.
    func runClaude(in directory: URL, command: String, filePath: String?)

    /// Paste a prompt into the terminal as input. If Claude Code is already running
    /// (interactive REPL mode), this becomes conversational input. If not, it's shell input.
    func injectPrompt(_ prompt: String)

    /// Best-effort: make the terminal view the first responder.
    func focus()
}

// MARK: - File Coordinator Protocol

/// Interface for file operations. Task 3 provides the concrete implementation.
protocol FileCoordinating: AnyObject {
    func openFile() async -> Bool
    func save() async -> Bool
    func saveAs() async -> Bool
    /// Auto-saves if enabled in settings and file has a URL. Returns true if saved or no save needed.
    func autoSaveIfNeeded() async -> Bool
}

// MARK: - App Settings

/// Persisted settings. Backed by UserDefaults.
class AppSettings: ObservableObject {
    @Published var claudeCommand: String {
        didSet { UserDefaults.standard.set(claudeCommand, forKey: "claudeCommand") }
    }
    @Published var autoSaveBeforeSend: Bool {
        didSet { UserDefaults.standard.set(autoSaveBeforeSend, forKey: "autoSaveBeforeSend") }
    }
    @Published var shellPath: String {
        didSet { UserDefaults.standard.set(shellPath, forKey: "shellPath") }
    }

    init() {
        self.claudeCommand = UserDefaults.standard.string(forKey: "claudeCommand") ?? "claude"
        self.autoSaveBeforeSend = UserDefaults.standard.object(forKey: "autoSaveBeforeSend") as? Bool ?? true
        self.shellPath = UserDefaults.standard.string(forKey: "shellPath") ?? "/bin/zsh"
    }
}
