import SwiftUI

struct ContentView: View {
    @EnvironmentObject var editorModel: EditorModel
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var terminalController: TerminalController
    @EnvironmentObject var fileCoordinator: FileCoordinator
    @EnvironmentObject var fileWatcher: FileWatcher
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            HSplitView {
                // MARK: - Terminal Pane (Task 1)
                TerminalPaneView()
                    .frame(minWidth: 300)

                // MARK: - Editor Pane (Task 2)
                VStack(spacing: 0) {
                    if editorModel.conflictBannerVisible {
                        ConflictBannerView()
                    }
                    MarkdownEditorView()
                }
                .frame(minWidth: 300)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await fileCoordinator.newFile() } }) {
                    Image(systemName: "doc.badge.plus")
                }
                .help("New file (⌘N)")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await fileCoordinator.openFile() } }) {
                    Image(systemName: "folder")
                }
                .help("Open a file (⌘O)")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await fileCoordinator.save() } }) {
                    Image(systemName: "sdcard")
                }
                .help("Save file (⌘S)")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    let dir = editorModel.currentFileURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: NSHomeDirectory())
                    terminalController.runClaude(in: dir, command: appSettings.claudeCommand, filePath: editorModel.currentFileURL?.path)
                }) {
                    Image(systemName: "terminal")
                }
                .help("Start Claude Code CLI (⌃⌘R)")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                }
                .help("Open settings (⌘,)")
            }
        }
        .navigationTitle(windowTitle)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appSettings)
        }
        .onAppear {
            fileWatcher.editorModel = editorModel
        }
        .onChange(of: editorModel.currentFileURL) { newURL in
            if let url = newURL {
                fileWatcher.watch(url: url)
            } else {
                fileWatcher.stopWatching()
            }
        }
    }

    private var windowTitle: String {
        let filename = editorModel.currentFileURL?.lastPathComponent ?? "Untitled"
        let dirty = editorModel.isDirty ? " (edited)" : ""
        return "\(filename)\(dirty) — TermMD"
    }
}

struct ConflictBannerView: View {
    @EnvironmentObject var editorModel: EditorModel
    @EnvironmentObject var fileWatcher: FileWatcher

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text("File changed on disk.")
            Spacer()
            Button("Reload") {
                fileWatcher.reloadFromDisk(editorModel: editorModel)
            }
            Button("Ignore") {
                editorModel.conflictBannerVisible = false
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
    }
}
