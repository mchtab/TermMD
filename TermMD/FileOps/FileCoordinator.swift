import Foundation
import AppKit
import CryptoKit
import UniformTypeIdentifiers

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
        // Allow plain text, .doc, and .docx files
        var allowedTypes: [UTType] = [.plainText]
        if let doc = UTType(filenameExtension: "doc") {
            allowedTypes.append(doc)
        }
        if let docx = UTType(filenameExtension: "docx") {
            allowedTypes.append(docx)
        }
        panel.allowedContentTypes = allowedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }

        let ext = url.pathExtension.lowercased()
        let isWordDoc = ext == "doc" || ext == "docx"

        // Handle Word documents - convert using textutil
        if isWordDoc {
            return await convertWordDocument(url: url)
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)

            // Check if it's a markdown file
            let isMarkdown = ext == "md" || ext == "markdown"

            var finalURL = url
            var finalContent = content

            if !isMarkdown {
                // Ask user if they want to convert to .md
                let alert = NSAlert()
                alert.messageText = "Convert to Markdown?"
                alert.informativeText = "'\(url.lastPathComponent)' is not a Markdown file. Would you like to save it as a new .md file?"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Save as .md")
                alert.addButton(withTitle: "Open Anyway")
                alert.addButton(withTitle: "Cancel")

                let result = alert.runModal()

                if result == .alertFirstButtonReturn {
                    // Save as .md
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.plainText]
                    let baseName = url.deletingPathExtension().lastPathComponent
                    savePanel.nameFieldStringValue = "\(baseName).md"
                    savePanel.directoryURL = url.deletingLastPathComponent()
                    savePanel.title = "Save as Markdown"

                    let saveResponse = savePanel.runModal()
                    guard saveResponse == .OK, let newURL = savePanel.url else { return false }

                    // Write content to new file
                    try finalContent.write(to: newURL, atomically: true, encoding: .utf8)
                    finalURL = newURL
                } else if result == .alertThirdButtonReturn {
                    // Cancel
                    return false
                }
                // alertSecondButtonReturn = Open Anyway, continue with original URL
            }

            editorModel.content = finalContent
            editorModel.currentFileURL = finalURL
            editorModel.isDirty = false
            editorModel.lastSavedHash = sha256(finalContent)
            editorModel.conflictBannerVisible = false

            // Auto-start Claude with this file
            let dir = finalURL.deletingLastPathComponent()
            terminalController?.runClaude(in: dir, command: appSettings.claudeCommand, filePath: finalURL.path)

            return true
        } catch {
            return false
        }
    }

    @MainActor
    private func convertWordDocument(url: URL) async -> Bool {
        // Show info alert
        let alert = NSAlert()
        alert.messageText = "Convert Word Document"
        alert.informativeText = "'\(url.lastPathComponent)' will be converted to Markdown. The original file will not be modified."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Convert")
        alert.addButton(withTitle: "Cancel")

        let result = alert.runModal()
        guard result == .alertFirstButtonReturn else { return false }

        // Ask where to save the .md file
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        let baseName = url.deletingPathExtension().lastPathComponent
        savePanel.nameFieldStringValue = "\(baseName).md"
        savePanel.directoryURL = url.deletingLastPathComponent()
        savePanel.title = "Save Converted Markdown"

        let saveResponse = savePanel.runModal()
        guard saveResponse == .OK, let newURL = savePanel.url else { return false }

        // Use textutil to convert to txt first
        let tempTxtURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(baseName).txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", "txt", "-output", tempTxtURL.path, url.path]

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                showError("Failed to convert document. textutil returned error.")
                return false
            }

            // Read the converted content
            let content = try String(contentsOf: tempTxtURL, encoding: .utf8)

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempTxtURL)

            // Write to final .md location
            try content.write(to: newURL, atomically: true, encoding: .utf8)

            // Load into editor
            editorModel.content = content
            editorModel.currentFileURL = newURL
            editorModel.isDirty = false
            editorModel.lastSavedHash = sha256(content)
            editorModel.conflictBannerVisible = false

            // Auto-start Claude with this file
            let dir = newURL.deletingLastPathComponent()
            terminalController?.runClaude(in: dir, command: appSettings.claudeCommand, filePath: newURL.path)

            return true
        } catch {
            showError("Failed to convert document: \(error.localizedDescription)")
            return false
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
