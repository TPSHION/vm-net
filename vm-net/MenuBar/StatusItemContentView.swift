//
//  StatusItemContentView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

final class StatusItemContentView: NSView {

    private enum Layout {
        static let viewWidth: CGFloat = 68
        static let horizontalPadding: CGFloat = 5
        static let verticalPadding: CGFloat = 1
    }

    private let labelsStack = NSStackView()
    private let uploadLabel = NSTextField(labelWithString: "0 B/s ↑")
    private let downloadLabel = NSTextField(labelWithString: "0 B/s ↓")

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
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(
        uploadText: String,
        downloadText: String
    ) {
        uploadLabel.stringValue = uploadText
        downloadLabel.stringValue = downloadText
        uploadLabel.alphaValue = 1
        downloadLabel.alphaValue = 1
    }

    private func setupView() {
        [uploadLabel, downloadLabel].forEach { label in
            label.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
            label.textColor = .labelColor
            label.alignment = .right
            label.lineBreakMode = .byClipping
            label.setContentCompressionResistancePriority(
                .required,
                for: .horizontal
            )
        }

        labelsStack.orientation = .vertical
        labelsStack.alignment = .trailing
        labelsStack.distribution = .fillEqually
        labelsStack.spacing = -1
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        labelsStack.addArrangedSubview(uploadLabel)
        labelsStack.addArrangedSubview(downloadLabel)

        addSubview(labelsStack)

        NSLayoutConstraint.activate([
            labelsStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Layout.horizontalPadding
            ),
            labelsStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Layout.horizontalPadding
            ),
            labelsStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Layout.verticalPadding
            ),
            labelsStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Layout.verticalPadding
            ),
        ])
    }
}
