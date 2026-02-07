import AppKit

class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        self.ruleThickness = 40

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(needsRedisplay),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(needsRedisplay),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func needsRedisplay() {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Only draw within our bounds
        let bounds = self.bounds

        // Background
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        // Separator line
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        drawLineNumbers()
    }

    private func drawLineNumbers() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = self.scrollView else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let visibleRect = scrollView.contentView.bounds
        let textContent = textView.string as NSString

        guard textContent.length > 0 else {
            // Draw "1" for empty document
            let drawPoint = NSPoint(x: ruleThickness - 16, y: textView.textContainerInset.height)
            "1".draw(at: drawPoint, withAttributes: attrs)
            return
        }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        // Count lines before visible area
        var lineNumber = 1
        for i in 0..<min(visibleCharRange.location, textContent.length) {
            if textContent.character(at: i) == 0x0A {
                lineNumber += 1
            }
        }

        // Draw visible line numbers
        var charIndex = visibleCharRange.location
        while charIndex < NSMaxRange(visibleCharRange) && charIndex < textContent.length {
            let lineRange = textContent.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineRect.origin.y += textView.textContainerInset.height
            lineRect.origin.y -= visibleRect.origin.y

            let lineStr = "\(lineNumber)"
            let strSize = lineStr.size(withAttributes: attrs)
            let drawPoint = NSPoint(
                x: ruleThickness - strSize.width - 8,
                y: lineRect.origin.y + (lineRect.height - strSize.height) / 2
            )
            lineStr.draw(at: drawPoint, withAttributes: attrs)

            lineNumber += 1
            charIndex = NSMaxRange(lineRange)
        }
    }
}
