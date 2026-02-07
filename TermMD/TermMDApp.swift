import SwiftUI

@main
struct TermMDApp: App {
    @StateObject private var editorModel = EditorModel()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var terminalController = TerminalController()
    @StateObject private var fileCoordinator: FileCoordinator
    @StateObject private var fileWatcher = FileWatcher()
    @State private var showSettings = false

    init() {
        let editor = EditorModel()
        let settings = AppSettings()
        let terminal = TerminalController()
        let coordinator = FileCoordinator(editorModel: editor, appSettings: settings)
        coordinator.terminalController = terminal
        _editorModel = StateObject(wrappedValue: editor)
        _appSettings = StateObject(wrappedValue: settings)
        _terminalController = StateObject(wrappedValue: terminal)
        _fileCoordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(showSettings: $showSettings)
                .environmentObject(editorModel)
                .environmentObject(appSettings)
                .environmentObject(terminalController)
                .environmentObject(fileCoordinator)
                .environmentObject(fileWatcher)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    Task { await fileCoordinator.newFile() }
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open...") {
                    Task { await fileCoordinator.openFile() }
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    Task { await fileCoordinator.save() }
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") {
                    Task { await fileCoordinator.saveAs() }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("Claude") {
                Button("Run Claude") {
                    let dir = editorModel.currentFileURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: NSHomeDirectory())
                    let fileArg = editorModel.currentFileURL?.path
                    terminalController.runClaude(in: dir, command: appSettings.claudeCommand, filePath: fileArg)
                }
                .keyboardShortcut("r", modifiers: [.command, .control])

                Button("Send to Claude (with line refs)") {
                    SendToClaudeAction.sendWithLineRefs(
                        editorModel: editorModel,
                        appSettings: appSettings,
                        fileCoordinator: fileCoordinator,
                        terminalController: terminalController
                    )
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
            }

            CommandMenu("Focus") {
                Button("Focus Terminal") {
                    terminalController.focus()
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Focus Editor") {
                    NotificationCenter.default.post(name: .focusEditor, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let focusEditor = Notification.Name("focusEditor")
    static let focusTerminal = Notification.Name("focusTerminal")
}
