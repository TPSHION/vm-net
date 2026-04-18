//
//  StatusItemContentView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

final class StatusItemContentView: NSView {

    private enum Layout {
        static let viewWidth: CGFloat = 44
        static let leadingPadding: CGFloat = 0
        static let trailingPadding: CGFloat = 0
        static let verticalPadding: CGFloat = 1
        static let lineSpacing: CGFloat = -1
        static let fontSize: CGFloat = 9
    }

    static let preferredWidth = Layout.viewWidth

    private var uploadText = "0 B/s ↑"
    private var downloadText = "0 B/s ↓"
    private lazy var textAttributes: [NSAttributedString.Key: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byClipping

        return [
            .font: NSFont.monospacedSystemFont(
                ofSize: Layout.fontSize,
                weight: .regular
            ),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle,
        ]
    }()

    override var allowsVibrancy: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: Layout.viewWidth,
            height: NSStatusBar.system.thickness
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(
        uploadText: String,
        downloadText: String
    ) {
        guard
            self.uploadText != uploadText
                || self.downloadText != downloadText
        else {
            return
        }

        self.uploadText = uploadText
        self.downloadText = downloadText
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = CGRect(
            x: self.bounds.minX + Layout.leadingPadding,
            y: self.bounds.minY + Layout.verticalPadding,
            width: max(
                self.bounds.width - Layout.leadingPadding - Layout.trailingPadding,
                0
            ),
            height: max(self.bounds.height - (Layout.verticalPadding * 2), 0)
        )
        let availableHeight = max(bounds.height, 0)
        let lineHeight = max(
            (availableHeight - Layout.lineSpacing) / 2,
            0
        )

        let uploadRect = CGRect(
            x: bounds.minX,
            y: bounds.minY + lineHeight + Layout.lineSpacing,
            width: bounds.width,
            height: lineHeight
        )
        let downloadRect = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: lineHeight
        )

        uploadText.draw(
            in: uploadRect,
            withAttributes: textAttributes
        )
        downloadText.draw(
            in: downloadRect,
            withAttributes: textAttributes
        )
    }

}
