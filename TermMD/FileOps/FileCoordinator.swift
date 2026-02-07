import Foundation
import AppKit
import CryptoKit

class FileCoordinator: ObservableObject, FileCoordinating {
    var editorModel: EditorModel
    var appSettings: AppSettings
    var terminalController: TerminalController?

    init(editorModel: EditorModel, appSettings: AppSettings) {
        self.editorModel = editorModel
        self.appSettings = appSettings
    }

    @MainActor
    @discardableResult
    func newFile() async -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Untitled.md"
        panel.title = "Create New Markdown File"
        panel.prompt = "Create"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }

        // Create empty file
        let content = ""
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            editorModel.content = content
            editorModel.currentFileURL = url
            editorModel.isDirty = false
            editorModel.lastSavedHash = sha256(content)
            editorModel.conflictBannerVisible = false

            // Auto-start Claude in this directory
            let dir = url.deletingLastPathComponent()
            terminalController?.runClaude(in: dir, command: appSettings.claudeCommand, filePath: url.path)

            return true
        } catch {
            return false
        }
    }

    @MainActor
    @discardableResult
    func openFile() async -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            editorModel.content = content
            editorModel.currentFileURL = url
            editorModel.isDirty = false
            editorModel.lastSavedHash = sha256(content)
            editorModel.conflictBannerVisible = false

            // Auto-start Claude with this file
            let dir = url.deletingLastPathComponent()
            terminalController?.runClaude(in: dir, command: appSettings.claudeCommand, filePath: url.path)

            return true
        } catch {
            return false
        }
    }

    @MainActor
    @discardableResult
    func save() async -> Bool {
        guard let url = editorModel.currentFileURL else {
            return await saveAs()
        }

        do {
            try editorModel.content.write(to: url, atomically: true, encoding: .utf8)
            editorModel.lastSavedHash = sha256(editorModel.content)
            editorModel.isDirty = false
            return true
        } catch {
            return false
        }
    }

    @MainActor
    @discardableResult
    func saveAs() async -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = editorModel.currentFileURL?.lastPathComponent ?? "Untitled.md"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }

        editorModel.currentFileURL = url
        return await save()
    }

    @MainActor
    @discardableResult
    func autoSaveIfNeeded() async -> Bool {
        guard appSettings.autoSaveBeforeSend else { return true }
        if editorModel.currentFileURL != nil {
            return await save()
        } else if !editorModel.content.isEmpty {
            return await saveAs()
        }
        return true
    }

    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
