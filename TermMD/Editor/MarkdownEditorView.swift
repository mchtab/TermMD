import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @EnvironmentObject var editorModel: EditorModel
    @EnvironmentObject var terminalController: TerminalController
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var fileCoordinator: FileCoordinator

    static let editorFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    static var textAttributes: [NSAttributedString.Key: Any] {
        [.font: editorFont, .foregroundColor: NSColor.textColor]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(editorModel: editorModel, terminalController: terminalController, appSettings: appSettings, fileCoordinator: fileCoordinator)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // Line number gutter (left)
        let lineNumberView = LineNumberGutterView()
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lineNumberView)

        // Create custom text view with context menu support
        let tv = ClaudeTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.isRichText = false
        tv.usesFontPanel = false
        tv.font = Self.editorFont
        tv.textColor = NSColor.textColor
        tv.backgroundColor = NSColor.textBackgroundColor
        tv.insertionPointColor = NSColor.textColor
        tv.typingAttributes = Self.textAttributes
        tv.textContainerInset = NSSize(width: 5, height: 8)
        tv.autoresizingMask = [.width, .height]
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true

        // Wrap in scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = tv
        container.addSubview(scrollView)

        // Layout
        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: container.topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            lineNumberView.widthAnchor.constraint(equalToConstant: 44),

            scrollView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Wire up coordinator
        tv.delegate = context.coordinator
        tv.coordinator = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.scrollView = scrollView
        context.coordinator.lineNumberView = lineNumberView
        lineNumberView.textView = tv

        // Observers
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.updateLineNumbers), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.updateLineNumbers), name: NSText.didChangeNotification, object: tv)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.focusEditor), name: .focusEditor, object: nil)

        // Initial content
        if !editorModel.content.isEmpty {
            context.coordinator.isUpdatingFromModel = true
            tv.textStorage?.setAttributedString(NSAttributedString(string: editorModel.content, attributes: Self.textAttributes))
            context.coordinator.isUpdatingFromModel = false
        }

        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        if textView.string != editorModel.content {
            context.coordinator.isUpdatingFromModel = true
            textView.textStorage?.setAttributedString(NSAttributedString(string: editorModel.content, attributes: Self.textAttributes))
            context.coordinator.lineNumberView?.needsDisplay = true
            context.coordinator.isUpdatingFromModel = false
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var editorModel: EditorModel
        var terminalController: TerminalController
        var appSettings: AppSettings
        var fileCoordinator: FileCoordinator
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        weak var lineNumberView: LineNumberGutterView?
        var isUpdatingFromModel = false

        init(editorModel: EditorModel, terminalController: TerminalController, appSettings: AppSettings, fileCoordinator: FileCoordinator) {
            self.editorModel = editorModel
            self.terminalController = terminalController
            self.appSettings = appSettings
            self.fileCoordinator = fileCoordinator
        }

        @objc func focusEditor() {
            textView?.window?.makeFirstResponder(textView)
        }

        @objc func updateLineNumbers() {
            lineNumberView?.needsDisplay = true
        }

        @objc func sendToClaudeWithLineRefs(_ sender: Any?) {
            SendToClaudeAction.sendWithLineRefs(editorModel: editorModel, appSettings: appSettings, fileCoordinator: fileCoordinator, terminalController: terminalController)
        }

        @objc func sendToClaudeSelectionOnly(_ sender: Any?) {
            SendToClaudeAction.sendSelectionOnly(editorModel: editorModel, appSettings: appSettings, fileCoordinator: fileCoordinator, terminalController: terminalController)
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromModel, let tv = textView else { return }
            editorModel.content = tv.string
            editorModel.isDirty = true
            lineNumberView?.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView else { return }
            let selectedRange = tv.selectedRange()
            editorModel.selectionNSRange = selectedRange

            if selectedRange.length > 0 {
                editorModel.selectedText = (tv.string as NSString).substring(with: selectedRange)

                let content = tv.string as NSString
                var startLine = 1
                for i in 0..<selectedRange.location where i < content.length {
                    if content.character(at: i) == 0x0A { startLine += 1 }
                }
                var endLine = startLine
                for i in selectedRange.location..<(selectedRange.location + selectedRange.length) where i < content.length {
                    if content.character(at: i) == 0x0A { endLine += 1 }
                }
                editorModel.selectionLineRange = startLine...endLine
            } else {
                editorModel.selectedText = ""
                editorModel.selectionLineRange = nil
            }
        }
    }
}

// MARK: - Custom Text View with Context Menu

class ClaudeTextView: NSTextView {
    weak var coordinator: MarkdownEditorView.Coordinator?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        // Add Claude items at the top if there's a selection
        if selectedRange().length > 0, let coord = coordinator {
            menu.insertItem(NSMenuItem.separator(), at: 0)

            let selectionItem = NSMenuItem(title: "Send to Claude (selection only)", action: #selector(coord.sendToClaudeSelectionOnly(_:)), keyEquivalent: "")
            selectionItem.target = coord
            menu.insertItem(selectionItem, at: 0)

            let lineRefsItem = NSMenuItem(title: "Send to Claude (with line refs)", action: #selector(coord.sendToClaudeWithLineRefs(_:)), keyEquivalent: "")
            lineRefsItem.target = coord
            menu.insertItem(lineRefsItem, at: 0)
        }

        return menu
    }
}

// MARK: - Line Number Gutter View

class LineNumberGutterView: NSView {
    weak var textView: NSTextView?
    private var dragStartLine: Int?

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let line = lineNumber(at: event) else { return }
        dragStartLine = line
        selectLines(from: line, to: line)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startLine = dragStartLine, let currentLine = lineNumber(at: event) else { return }
        selectLines(from: min(startLine, currentLine), to: max(startLine, currentLine))
    }

    override func mouseUp(with event: NSEvent) {
        dragStartLine = nil
    }

    private func lineNumber(at event: NSEvent) -> Int? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView else { return nil }

        let localPoint = convert(event.locationInWindow, from: nil)
        let visibleRect = scrollView.contentView.bounds
        let textContent = textView.string as NSString

        guard textContent.length > 0 else { return 1 }

        let textY = localPoint.y + visibleRect.origin.y - textView.textContainerInset.height
        let charIndex = layoutManager.characterIndex(for: NSPoint(x: 0, y: textY), in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        var lineNum = 1
        for i in 0..<min(charIndex, textContent.length) {
            if textContent.character(at: i) == 0x0A { lineNum += 1 }
        }
        return lineNum
    }

    private func selectLines(from startLine: Int, to endLine: Int) {
        guard let textView = textView else { return }
        let textContent = textView.string as NSString

        var currentLine = 1
        var startIndex = 0
        var endIndex = textContent.length

        for i in 0..<textContent.length {
            if currentLine == startLine {
                startIndex = i
                break
            }
            if textContent.character(at: i) == 0x0A { currentLine += 1 }
        }

        currentLine = 1
        for i in 0..<textContent.length {
            if textContent.character(at: i) == 0x0A {
                if currentLine == endLine {
                    endIndex = i + 1
                    break
                }
                currentLine += 1
            }
        }

        textView.setSelectedRange(NSRange(location: startIndex, length: endIndex - startIndex))
        textView.window?.makeFirstResponder(textView)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: 0, width: 1, height: bounds.height).fill()

        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let visibleRect = scrollView.contentView.bounds
        let textContent = textView.string as NSString

        guard textContent.length > 0 else {
            "1".draw(at: NSPoint(x: bounds.width - 20, y: textView.textContainerInset.height), withAttributes: attrs)
            return
        }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        var lineNumber = 1
        for i in 0..<min(visibleCharRange.location, textContent.length) {
            if textContent.character(at: i) == 0x0A { lineNumber += 1 }
        }

        var charIndex = visibleCharRange.location
        while charIndex < NSMaxRange(visibleCharRange) && charIndex < textContent.length {
            let lineRange = textContent.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineRect.origin.y += textView.textContainerInset.height
            lineRect.origin.y -= visibleRect.origin.y

            let lineStr = "\(lineNumber)"
            let strSize = lineStr.size(withAttributes: attrs)
            lineStr.draw(at: NSPoint(x: bounds.width - strSize.width - 8, y: lineRect.origin.y + (lineRect.height - strSize.height) / 2), withAttributes: attrs)

            lineNumber += 1
            charIndex = NSMaxRange(lineRange)
        }
    }
}
