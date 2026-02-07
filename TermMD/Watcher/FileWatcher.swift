import Foundation
import CryptoKit

class FileWatcher: ObservableObject {
    weak var editorModel: EditorModel?
    private var timer: Timer?
    private var watchedURL: URL?
    private var lastKnownModDate: Date?

    func watch(url: URL) {
        stopWatching()
        watchedURL = url
        lastKnownModDate = modificationDate(for: url)

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
        watchedURL = nil
        lastKnownModDate = nil
    }

    private func checkForChanges() {
        guard let url = watchedURL, let editorModel = editorModel else { return }

        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.async {
                editorModel.conflictBannerVisible = false
            }
            stopWatching()
            return
        }

        let currentModDate = modificationDate(for: url)
        guard currentModDate != lastKnownModDate else { return }
        lastKnownModDate = currentModDate

        guard let diskContent = try? String(contentsOf: url, encoding: .utf8) else { return }
        let diskHash = sha256(diskContent)

        // If the hash matches what we last saved, this is our own save — ignore
        if diskHash == editorModel.lastSavedHash { return }

        DispatchQueue.main.async {
            if editorModel.isDirty {
                editorModel.conflictBannerVisible = true
            } else {
                editorModel.content = diskContent
                editorModel.lastSavedHash = diskHash
                editorModel.isDirty = false
            }
        }
    }

    @MainActor
    func reloadFromDisk(editorModel: EditorModel) {
        guard let url = watchedURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        editorModel.content = content
        editorModel.lastSavedHash = sha256(content)
        editorModel.isDirty = false
        editorModel.conflictBannerVisible = false
        lastKnownModDate = modificationDate(for: url)
    }

    private func modificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    deinit {
        stopWatching()
    }
}
