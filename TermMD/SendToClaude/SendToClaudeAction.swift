import Foundation

struct SendToClaudeAction {

    static func sendWithLineRefs(
        editorModel: EditorModel,
        appSettings: AppSettings,
        fileCoordinator: FileCoordinator,
        terminalController: TerminalController
    ) {
        guard !editorModel.selectedText.isEmpty else { return }

        Task { @MainActor in
            if appSettings.autoSaveBeforeSend {
                let saved = await fileCoordinator.autoSaveIfNeeded()
                if !saved {
                    // User cancelled save — send anyway but without file path
                }
            }

            let prompt = SendToClaudeBuilder.buildWithLineRefs(
                fileURL: editorModel.currentFileURL,
                lineRange: editorModel.selectionLineRange,
                selectedText: editorModel.selectedText
            )
            terminalController.injectPrompt(prompt)
            terminalController.focus()
        }
    }

    static func sendSelectionOnly(
        editorModel: EditorModel,
        appSettings: AppSettings,
        fileCoordinator: FileCoordinator,
        terminalController: TerminalController
    ) {
        guard !editorModel.selectedText.isEmpty else { return }

        Task { @MainActor in
            if appSettings.autoSaveBeforeSend {
                let saved = await fileCoordinator.autoSaveIfNeeded()
                if !saved {
                    // User cancelled save — send anyway
                }
            }

            let prompt = SendToClaudeBuilder.buildSelectionOnly(
                selectedText: editorModel.selectedText
            )
            terminalController.injectPrompt(prompt)
            terminalController.focus()
        }
    }
}
