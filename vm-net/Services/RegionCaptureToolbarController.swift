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
        static let buttonSize = NSSize(width: 30, height: 30)
        static let buttonSpacing: CGFloat = 6
        static let sectionSpacing: CGFloat = 10
        static let separatorHeight: CGFloat = 22
        static let separatorWidth: CGFloat = 1
        static let cornerRadius: CGFloat = 10
        static let itemMaskCornerRadius: CGFloat = 7
        static let symbolPointSize: CGFloat = 17
    }

    private enum Color {
        static let background = NSColor.white.withAlphaComponent(0.98)
        static let border = NSColor.black.withAlphaComponent(0.1)
        static let itemHoverMask = NSColor.black.withAlphaComponent(0.08)
        static let itemPressedMask = NSColor.black.withAlphaComponent(0.14)
        static let symbol = NSColor(
            calibratedWhite: 0.18,
            alpha: 0.92
        )
        static let accent = NSColor.systemBlue
        static let separator = NSColor.black.withAlphaComponent(0.08)
    }

    private enum OrnamentTool: CaseIterable {
        case rectangle
        case ellipse
        case arrow
        case pen
        case mosaic
        case text
        case tag
        case textRecognition
        case undo

        var symbolNames: [String] {
            switch self {
            case .rectangle:
                return ["square"]
            case .ellipse:
                return ["circle"]
            case .arrow:
                return ["arrow.up.forward"]
            case .pen:
                return ["pencil"]
            case .mosaic:
                return ["square.grid.2x2", "checkerboard.rectangle"]
            case .text:
                return ["textformat"]
            case .tag:
                return ["tag"]
            case .textRecognition:
                return ["translate", "character.textbox", "text.viewfinder"]
            case .undo:
                return ["arrow.uturn.backward"]
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .rectangle:
                return L10n.tr("screenshot.toolbar.rectangle")
            case .ellipse:
                return L10n.tr("screenshot.toolbar.ellipse")
            case .arrow:
                return L10n.tr("screenshot.toolbar.arrow")
            case .pen:
                return L10n.tr("screenshot.toolbar.pen")
            case .mosaic:
                return L10n.tr("screenshot.toolbar.mosaic")
            case .text:
                return L10n.tr("screenshot.toolbar.text")
            case .tag:
                return L10n.tr("screenshot.toolbar.tag")
            case .textRecognition:
                return L10n.tr("screenshot.toolbar.textRecognition")
            case .undo:
                return L10n.tr("screenshot.toolbar.undo")
            }
        }
    }

    var saveToFileHandler: (() -> Void)?
    var copyToClipboardHandler: (() -> Void)?
    var cancelHandler: (() -> Void)?

    private let contentContainerView = NSView()
    private let backgroundView = NSView()
    private let stackView = NSStackView()

    private lazy var saveToFileButton = makeActionButton(
        accessibilityLabel: L10n.tr("screenshot.toolbar.saveToFile"),
        symbolName: "square.and.arrow.down",
        tintColor: Color.symbol,
        action: #selector(handleSaveToFile)
    )

    private lazy var copyToClipboardButton = makeActionButton(
        accessibilityLabel: L10n.tr("screenshot.toolbar.copyToClipboard"),
        symbolName: "checkmark",
        tintColor: Color.accent,
        action: #selector(handleCopyToClipboard)
    )

    private lazy var cancelButton = makeActionButton(
        accessibilityLabel: L10n.tr("screenshot.toolbar.cancel"),
        symbolName: "xmark",
        tintColor: Color.symbol,
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
        let contentSize = backgroundView.fittingSize
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
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.level = NSWindow.Level(
            rawValue: NSWindow.Level.statusBar.rawValue + 1
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func configureContent() {
        contentContainerView.wantsLayer = true
        contentContainerView.layer?.backgroundColor = NSColor.clear.cgColor

        backgroundView.wantsLayer = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer?.backgroundColor = Color.background.cgColor
        backgroundView.layer?.cornerRadius = Layout.cornerRadius
        backgroundView.layer?.cornerCurve = .continuous
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = Color.border.cgColor

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.spacing = Layout.buttonSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setHuggingPriority(.required, for: .horizontal)
        stackView.setHuggingPriority(.required, for: .vertical)

        let toolbarItems: [NSView] = [
            makeOrnamentView(for: .rectangle),
            makeOrnamentView(for: .ellipse),
            makeOrnamentView(for: .arrow),
            makeOrnamentView(for: .pen),
            makeOrnamentView(for: .mosaic),
            makeSeparator(),
            makeOrnamentView(for: .text),
            makeOrnamentView(for: .tag),
            makeOrnamentView(for: .textRecognition),
            makeSeparator(),
            makeOrnamentView(for: .undo),
            makeSeparator(),
            saveToFileButton,
            cancelButton,
            copyToClipboardButton,
        ]

        toolbarItems.forEach {
            stackView.addArrangedSubview($0)
        }

        contentContainerView.addSubview(backgroundView)
        backgroundView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor,
                constant: Layout.horizontalPadding
            ),
            stackView.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -Layout.horizontalPadding
            ),
            stackView.topAnchor.constraint(
                equalTo: backgroundView.topAnchor,
                constant: Layout.verticalPadding
            ),
            stackView.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor,
                constant: -Layout.verticalPadding
            ),
            backgroundView.leadingAnchor.constraint(
                equalTo: contentContainerView.leadingAnchor
            ),
            backgroundView.trailingAnchor.constraint(
                equalTo: contentContainerView.trailingAnchor
            ),
            backgroundView.topAnchor.constraint(
                equalTo: contentContainerView.topAnchor
            ),
            backgroundView.bottomAnchor.constraint(
                equalTo: contentContainerView.bottomAnchor
            ),
        ])

        window?.contentView = contentContainerView
    }

    private func makeActionButton(
        accessibilityLabel: String,
        symbolName: String,
        tintColor: NSColor,
        action: Selector
    ) -> NSButton {
        let button = RegionCaptureToolbarButton(
            image: makeSymbolImage(
                preferredNames: [symbolName],
                accessibilityLabel: accessibilityLabel
            ),
            maskCornerRadius: Layout.itemMaskCornerRadius,
            hoverMaskColor: Color.itemHoverMask,
            pressedMaskColor: Color.itemPressedMask,
            target: self,
            action: action
        )
        button.contentTintColor = tintColor
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
        button.toolTip = accessibilityLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(
            equalToConstant: Layout.buttonSize.width
        ).isActive = true
        button.heightAnchor.constraint(
            equalToConstant: Layout.buttonSize.height
        ).isActive = true
        return button
    }

    private func makeOrnamentView(
        for tool: OrnamentTool
    ) -> NSView {
        let container = RegionCaptureToolbarOrnamentView(
            maskCornerRadius: Layout.itemMaskCornerRadius,
            hoverMaskColor: Color.itemHoverMask
        )
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(
            equalToConstant: Layout.buttonSize.width
        ).isActive = true
        container.heightAnchor.constraint(
            equalToConstant: Layout.buttonSize.height
        ).isActive = true
        container.toolTip = tool.accessibilityLabel

        let imageView = NSImageView(
            image: makeSymbolImage(
                preferredNames: tool.symbolNames,
                accessibilityLabel: tool.accessibilityLabel
            )
        )
        imageView.contentTintColor = Color.symbol
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Layout.symbolPointSize,
            weight: .regular
        )
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(
                equalTo: container.centerXAnchor
            ),
            imageView.centerYAnchor.constraint(
                equalTo: container.centerYAnchor
            ),
        ])
        return container
    }

    private func makeSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = Color.separator.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(
            equalToConstant: Layout.separatorWidth
        ).isActive = true
        separator.heightAnchor.constraint(
            equalToConstant: Layout.separatorHeight
        ).isActive = true

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(
            equalToConstant: Layout.sectionSpacing
        ).isActive = true
        container.heightAnchor.constraint(
            equalToConstant: Layout.buttonSize.height
        ).isActive = true
        container.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    private func makeSymbolImage(
        preferredNames: [String],
        accessibilityLabel: String
    ) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: Layout.symbolPointSize,
            weight: .regular
        )

        for symbolName in preferredNames {
            if let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: accessibilityLabel
            )?.withSymbolConfiguration(configuration) {
                return image
            }
        }

        return NSImage(
            systemSymbolName: "questionmark",
            accessibilityDescription: accessibilityLabel
        )?.withSymbolConfiguration(configuration) ?? NSImage()
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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class RegionCaptureToolbarButton: NSButton {

    private var maskCornerRadius: CGFloat = 0
    private var hoverMaskColor: NSColor = .clear
    private var pressedMaskColor: NSColor = .clear

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    init(
        image: NSImage,
        maskCornerRadius: CGFloat,
        hoverMaskColor: NSColor,
        pressedMaskColor: NSColor,
        target: AnyObject?,
        action: Selector?
    ) {
        self.maskCornerRadius = maskCornerRadius
        self.hoverMaskColor = hoverMaskColor
        self.pressedMaskColor = pressedMaskColor
        super.init(frame: .zero)
        self.image = image
        self.target = target
        self.action = action
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = maskCornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateMask(isHovered: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateMask(isHovered: false)
    }

    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = pressedMaskColor.cgColor
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let hovered = bounds.contains(convert(event.locationInWindow, from: nil))
        updateMask(isHovered: hovered)
    }

    private func updateMask(isHovered: Bool) {
        layer?.backgroundColor = isHovered
            ? hoverMaskColor.cgColor
            : NSColor.clear.cgColor
    }
}

private final class RegionCaptureToolbarOrnamentView: NSView {

    private let maskCornerRadius: CGFloat
    private let hoverMaskColor: NSColor

    init(
        maskCornerRadius: CGFloat,
        hoverMaskColor: NSColor
    ) {
        self.maskCornerRadius = maskCornerRadius
        self.hoverMaskColor = hoverMaskColor
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = maskCornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        layer?.backgroundColor = hoverMaskColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}
