//
//  StatusItemContentView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

final class StatusItemContentView: NSView {

    private enum Layout {
        static let viewWidth: CGFloat = 94
        static let iconSize: CGFloat = 14
        static let labelWidth: CGFloat = 68
        static let horizontalPadding: CGFloat = 4
        static let verticalPadding: CGFloat = 1
        static let stackSpacing: CGFloat = 4
    }

    private let rootStack = NSStackView()
    private let labelsStack = NSStackView()
    private let iconImageView = NSImageView()
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

    func render(uploadText: String, downloadText: String) {
        uploadLabel.stringValue = uploadText
        downloadLabel.stringValue = downloadText
    }

    private func setupView() {
        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 11,
            weight: .medium
        )

        iconImageView.image = NSImage(
            systemSymbolName: "arrow.up.arrow.down.circle.fill",
            accessibilityDescription: "Network throughput"
        )?.withSymbolConfiguration(symbolConfiguration)
        iconImageView.contentTintColor = .labelColor
        iconImageView.setContentHuggingPriority(.required, for: .horizontal)

        [uploadLabel, downloadLabel].forEach { label in
            label.font = .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
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
        labelsStack.addArrangedSubview(uploadLabel)
        labelsStack.addArrangedSubview(downloadLabel)

        rootStack.orientation = .horizontal
        rootStack.alignment = .centerY
        rootStack.spacing = Layout.stackSpacing
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(iconImageView)
        rootStack.addArrangedSubview(labelsStack)

        addSubview(rootStack)

        NSLayoutConstraint.activate([
            labelsStack.widthAnchor.constraint(equalToConstant: Layout.labelWidth),
            iconImageView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            iconImageView.heightAnchor.constraint(
                equalToConstant: Layout.iconSize
            ),
            rootStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Layout.horizontalPadding
            ),
            rootStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Layout.horizontalPadding
            ),
            rootStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Layout.verticalPadding
            ),
            rootStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Layout.verticalPadding
            ),
        ])
    }
}
