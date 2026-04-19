//
//  RegionCaptureToolbarController.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit

@MainActor
final class RegionCaptureToolbarController: NSWindowController {

    private enum Layout {
        static let margin: CGFloat = 14
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 10
        static let buttonSpacing: CGFloat = 10
    }

    var saveToFileHandler: (() -> Void)?
    var copyToClipboardHandler: (() -> Void)?
    var cancelHandler: (() -> Void)?

    private let materialView = NSVisualEffectView()
    private let stackView = NSStackView()

    private lazy var saveToFileButton = makeButton(
        title: L10n.tr("screenshot.toolbar.saveToFile"),
        symbolName: "square.and.arrow.down",
        action: #selector(handleSaveToFile)
    )

    private lazy var copyToClipboardButton = makeButton(
        title: L10n.tr("screenshot.toolbar.copyToClipboard"),
        symbolName: "checkmark",
        action: #selector(handleCopyToClipboard)
    )

    private lazy var cancelButton = makeButton(
        title: L10n.tr("screenshot.toolbar.cancel"),
        symbolName: "xmark",
        action: #selector(handleCancel)
    )

    init() {
        let panel = RegionCaptureToolbarPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)
        configurePanel(panel)
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(for selection: RegionSelection) {
        guard let window else { return }
        let screen = selection.originScreen

        stackView.layoutSubtreeIfNeeded()
        let contentSize = materialView.fittingSize
        let frame = toolbarFrame(
            for: selection.rect,
            contentSize: contentSize,
            visibleFrame: screen.visibleFrame
        )

        window.setFrame(frame, display: false)
        window.alphaValue = 1
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func configurePanel(_ panel: RegionCaptureToolbarPanel) {
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func configureContent() {
        materialView.material = .popover
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 16
        materialView.layer?.masksToBounds = true

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillProportionally
        stackView.spacing = Layout.buttonSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        [saveToFileButton, copyToClipboardButton, cancelButton].forEach {
            stackView.addArrangedSubview($0)
        }

        materialView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: materialView.leadingAnchor,
                constant: Layout.horizontalPadding
            ),
            stackView.trailingAnchor.constraint(
                equalTo: materialView.trailingAnchor,
                constant: -Layout.horizontalPadding
            ),
            stackView.topAnchor.constraint(
                equalTo: materialView.topAnchor,
                constant: Layout.verticalPadding
            ),
            stackView.bottomAnchor.constraint(
                equalTo: materialView.bottomAnchor,
                constant: -Layout.verticalPadding
            ),
        ])

        window?.contentView = materialView
    }

    private func makeButton(
        title: String,
        symbolName: String,
        action: Selector
    ) -> NSButton {
        let button = NSButton(
            title: title,
            target: self,
            action: action
        )
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: title
        )
        button.imagePosition = .imageLeading
        button.bezelStyle = .texturedRounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.setButtonType(.momentaryPushIn)
        return button
    }

    private func toolbarFrame(
        for selectionRect: CGRect,
        contentSize: NSSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let x = min(
            max(selectionRect.midX - (contentSize.width / 2), visibleFrame.minX + Layout.margin),
            visibleFrame.maxX - contentSize.width - Layout.margin
        )

        let preferredBelowY = selectionRect.minY - contentSize.height - Layout.margin
        if preferredBelowY >= visibleFrame.minY + Layout.margin {
            return CGRect(
                x: x,
                y: preferredBelowY,
                width: contentSize.width,
                height: contentSize.height
            )
        }

        let preferredAboveY = selectionRect.maxY + Layout.margin
        if preferredAboveY + contentSize.height <= visibleFrame.maxY - Layout.margin {
            return CGRect(
                x: x,
                y: preferredAboveY,
                width: contentSize.width,
                height: contentSize.height
            )
        }

        return CGRect(
            x: x,
            y: max(
                visibleFrame.minY + Layout.margin,
                visibleFrame.maxY - contentSize.height - Layout.margin
            ),
            width: contentSize.width,
            height: contentSize.height
        )
    }

    @objc
    private func handleSaveToFile() {
        saveToFileHandler?()
    }

    @objc
    private func handleCopyToClipboard() {
        copyToClipboardHandler?()
    }

    @objc
    private func handleCancel() {
        cancelHandler?()
    }
}

private final class RegionCaptureToolbarPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
