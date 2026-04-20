//
//  RegionCaptureToolbarController.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit

@MainActor
final class RegionCaptureToolbarController: NSWindowController {

    struct State: Equatable {
        var isRectangleToolSelected: Bool
        var isEllipseToolSelected: Bool
        var isPenToolSelected: Bool
        var isArrowToolSelected: Bool
        var selectedStrokeSize: RegionCaptureStrokeSize
        var selectedStrokeColor: RegionCaptureAnnotationColor
        var canUndo: Bool
        var showsSecondaryToolbar: Bool
        var highlightedTool: RegionCaptureTool?
    }

    private enum Layout {
        static let margin: CGFloat = 14
        static let interToolbarSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 10
        static let secondaryHorizontalPadding: CGFloat = 10
        static let secondaryVerticalPadding: CGFloat = 8
        static let buttonSize = NSSize(width: 30, height: 30)
        static let secondaryButtonSize = NSSize(width: 28, height: 28)
        static let colorSwatchSize: CGFloat = 18
        static let colorSwatchCornerRadius: CGFloat = 4
        static let buttonSpacing: CGFloat = 6
        static let sectionSpacing: CGFloat = 10
        static let separatorHeight: CGFloat = 22
        static let separatorWidth: CGFloat = 1
        static let cornerRadius: CGFloat = 10
        static let itemMaskCornerRadius: CGFloat = 7
        static let symbolPointSize: CGFloat = 17
        static let compactActionSymbolPointSize: CGFloat = 15
    }

    private enum Color {
        static let background = NSColor.white.withAlphaComponent(0.98)
        static let border = NSColor.black.withAlphaComponent(0.1)
        static let itemHoverMask = NSColor.black.withAlphaComponent(0.08)
        static let itemPressedMask = NSColor.black.withAlphaComponent(0.14)
        static let itemSelectedMask = NSColor.systemBlue.withAlphaComponent(0.14)
        static let symbol = NSColor(
            calibratedWhite: 0.18,
            alpha: 0.92
        )
        static let disabledSymbol = NSColor(
            calibratedWhite: 0.18,
            alpha: 0.28
        )
        static let accent = NSColor.systemBlue
        static let separator = NSColor.black.withAlphaComponent(0.08)
    }

    private enum OrnamentTool {
        case rectangle
        case ellipse
        case arrow
        case pen
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
            case .undo:
                return L10n.tr("screenshot.toolbar.undo")
            }
        }
    }

    var saveToFileHandler: (() -> Void)?
    var copyToClipboardHandler: (() -> Void)?
    var cancelHandler: (() -> Void)?
    var rectangleToolHandler: (() -> Void)?
    var ellipseToolHandler: (() -> Void)?
    var penToolHandler: (() -> Void)?
    var arrowToolHandler: (() -> Void)?
    var strokeSizeHandler: ((RegionCaptureStrokeSize) -> Void)?
    var strokeColorHandler: ((RegionCaptureAnnotationColor) -> Void)?
    var undoHandler: (() -> Void)?

    private var state = State(
        isRectangleToolSelected: false,
        isEllipseToolSelected: false,
        isPenToolSelected: false,
        isArrowToolSelected: false,
        selectedStrokeSize: .medium,
        selectedStrokeColor: .blue,
        canUndo: false,
        showsSecondaryToolbar: false,
        highlightedTool: nil
    )
    private var currentSelection: RegionSelection?

    private let contentContainerView = NSView()
    private let rootStackView = NSStackView()
    private let primaryBackgroundView = NSView()
    private let primaryStackView = NSStackView()
    private let secondaryBackgroundView = NSView()
    private let secondaryStackView = NSStackView()

    private lazy var rectangleToolButton = makeSelectableToolButton(
        for: .rectangle,
        action: #selector(handleRectangleTool)
    )

    private lazy var ellipseToolButton = makeSelectableToolButton(
        for: .ellipse,
        action: #selector(handleEllipseTool)
    )

    private lazy var penToolButton = makeSelectableToolButton(
        for: .pen,
        action: #selector(handlePenTool)
    )

    private lazy var arrowToolButton = makeSelectableToolButton(
        for: .arrow,
        action: #selector(handleArrowTool)
    )

    private lazy var undoButton = makeSelectableToolButton(
        for: .undo,
        action: #selector(handleUndo)
    ).withHoverClearedAfterAction()

    private lazy var saveToFileButton = makeActionButton(
        accessibilityLabel: L10n.tr("screenshot.toolbar.saveToFile"),
        symbolName: "arrow.down.to.line",
        symbolPointSize: Layout.compactActionSymbolPointSize,
        tintColor: Color.symbol,
        action: #selector(handleSaveToFile)
    )

    private lazy var copyToClipboardButton = makeActionButton(
        accessibilityLabel: L10n.tr("screenshot.toolbar.copyToClipboard"),
        symbolName: "checkmark",
        symbolPointSize: Layout.symbolPointSize,
        tintColor: Color.accent,
        action: #selector(handleCopyToClipboard)
    )

    private lazy var cancelButton = makeActionButton(
        accessibilityLabel: L10n.tr("screenshot.toolbar.cancel"),
        symbolName: "xmark",
        symbolPointSize: Layout.symbolPointSize,
        tintColor: Color.symbol,
        action: #selector(handleCancel)
    )

    private lazy var strokeSizeButtons: [(RegionCaptureStrokeSize, RegionCaptureToolbarSelectableButton)] =
        RegionCaptureStrokeSize.allCases.map { size in
            (size, makeStrokeSizeButton(for: size))
        }

    private lazy var strokeColorButtons: [(RegionCaptureAnnotationColor, RegionCaptureToolbarSelectableButton)] =
        RegionCaptureAnnotationColor.allCases.map { color in
            (color, makeStrokeColorButton(for: color))
        }

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
        applyState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(state: State) {
        guard self.state != state else { return }
        self.state = state
        applyState()
    }

    func show(for selection: RegionSelection) {
        guard let window else { return }
        currentSelection = selection

        rootStackView.layoutSubtreeIfNeeded()
        let contentSize = rootStackView.fittingSize
        let frame = toolbarFrame(
            for: selection.rect,
            contentSize: contentSize,
            visibleFrame: selection.originScreen.visibleFrame
        )

        window.setFrame(frame, display: false)
        window.alphaValue = 1
        window.orderFrontRegardless()
    }

    func hide() {
        currentSelection = nil
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

        rootStackView.orientation = .vertical
        rootStackView.alignment = .centerX
        rootStackView.spacing = Layout.interToolbarSpacing
        rootStackView.detachesHiddenViews = true
        rootStackView.translatesAutoresizingMaskIntoConstraints = false

        configureBackground(primaryBackgroundView)
        configureBackground(secondaryBackgroundView)

        configurePrimaryStack()
        configureSecondaryStack()

        contentContainerView.addSubview(rootStackView)
        rootStackView.addArrangedSubview(primaryBackgroundView)
        rootStackView.addArrangedSubview(secondaryBackgroundView)

        NSLayoutConstraint.activate([
            rootStackView.leadingAnchor.constraint(
                equalTo: contentContainerView.leadingAnchor
            ),
            rootStackView.trailingAnchor.constraint(
                equalTo: contentContainerView.trailingAnchor
            ),
            rootStackView.topAnchor.constraint(
                equalTo: contentContainerView.topAnchor
            ),
            rootStackView.bottomAnchor.constraint(
                equalTo: contentContainerView.bottomAnchor
            ),
        ])

        window?.contentView = contentContainerView
    }

    private func configureBackground(_ view: NSView) {
        view.wantsLayer = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer?.backgroundColor = Color.background.cgColor
        view.layer?.cornerRadius = Layout.cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 1
        view.layer?.borderColor = Color.border.cgColor
    }

    private func configurePrimaryStack() {
        primaryStackView.orientation = .horizontal
        primaryStackView.alignment = .centerY
        primaryStackView.distribution = .gravityAreas
        primaryStackView.spacing = Layout.buttonSpacing
        primaryStackView.translatesAutoresizingMaskIntoConstraints = false
        primaryStackView.setHuggingPriority(.required, for: .horizontal)
        primaryStackView.setHuggingPriority(.required, for: .vertical)

        let toolbarItems: [NSView] = [
            rectangleToolButton,
            ellipseToolButton,
            penToolButton,
            arrowToolButton,
            makeSeparator(),
            undoButton,
            makeSeparator(),
            saveToFileButton,
            cancelButton,
            copyToClipboardButton,
        ]

        toolbarItems.forEach { primaryStackView.addArrangedSubview($0) }
        primaryBackgroundView.addSubview(primaryStackView)

        NSLayoutConstraint.activate([
            primaryStackView.leadingAnchor.constraint(
                equalTo: primaryBackgroundView.leadingAnchor,
                constant: Layout.horizontalPadding
            ),
            primaryStackView.trailingAnchor.constraint(
                equalTo: primaryBackgroundView.trailingAnchor,
                constant: -Layout.horizontalPadding
            ),
            primaryStackView.topAnchor.constraint(
                equalTo: primaryBackgroundView.topAnchor,
                constant: Layout.verticalPadding
            ),
            primaryStackView.bottomAnchor.constraint(
                equalTo: primaryBackgroundView.bottomAnchor,
                constant: -Layout.verticalPadding
            ),
        ])
    }

    private func configureSecondaryStack() {
        secondaryStackView.orientation = .horizontal
        secondaryStackView.alignment = .centerY
        secondaryStackView.distribution = .gravityAreas
        secondaryStackView.spacing = Layout.buttonSpacing
        secondaryStackView.translatesAutoresizingMaskIntoConstraints = false
        secondaryStackView.setHuggingPriority(.required, for: .horizontal)
        secondaryStackView.setHuggingPriority(.required, for: .vertical)

        strokeSizeButtons.forEach { _, button in
            secondaryStackView.addArrangedSubview(button)
        }
        secondaryStackView.addArrangedSubview(makeSeparator())
        strokeColorButtons.forEach { _, button in
            secondaryStackView.addArrangedSubview(button)
        }

        secondaryBackgroundView.addSubview(secondaryStackView)
        NSLayoutConstraint.activate([
            secondaryStackView.leadingAnchor.constraint(
                equalTo: secondaryBackgroundView.leadingAnchor,
                constant: Layout.secondaryHorizontalPadding
            ),
            secondaryStackView.trailingAnchor.constraint(
                equalTo: secondaryBackgroundView.trailingAnchor,
                constant: -Layout.secondaryHorizontalPadding
            ),
            secondaryStackView.topAnchor.constraint(
                equalTo: secondaryBackgroundView.topAnchor,
                constant: Layout.secondaryVerticalPadding
            ),
            secondaryStackView.bottomAnchor.constraint(
                equalTo: secondaryBackgroundView.bottomAnchor,
                constant: -Layout.secondaryVerticalPadding
            ),
        ])
    }

    private func makeActionButton(
        accessibilityLabel: String,
        symbolName: String,
        symbolPointSize: CGFloat,
        tintColor: NSColor,
        action: Selector
    ) -> NSButton {
        let button = RegionCaptureToolbarButton(
            image: makeSymbolImage(
                preferredNames: [symbolName],
                accessibilityLabel: accessibilityLabel,
                pointSize: symbolPointSize
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

    private func makeSelectableToolButton(
        for tool: OrnamentTool,
        action: Selector
    ) -> RegionCaptureToolbarSelectableButton {
        let button = RegionCaptureToolbarSelectableButton(
            image: makeSymbolImage(
                preferredNames: tool.symbolNames,
                accessibilityLabel: tool.accessibilityLabel
            ),
            maskCornerRadius: Layout.itemMaskCornerRadius,
            hoverMaskColor: Color.itemHoverMask,
            pressedMaskColor: Color.itemPressedMask,
            selectedMaskColor: Color.itemSelectedMask,
            defaultTintColor: Color.symbol,
            selectedTintColor: Color.accent,
            disabledTintColor: Color.disabledSymbol,
            target: self,
            action: action
        )
        button.imagePosition = .imageOnly
        button.toolTip = tool.accessibilityLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(
            equalToConstant: Layout.buttonSize.width
        ).isActive = true
        button.heightAnchor.constraint(
            equalToConstant: Layout.buttonSize.height
        ).isActive = true
        return button
    }

    private func makeStrokeSizeButton(
        for size: RegionCaptureStrokeSize
    ) -> RegionCaptureToolbarSelectableButton {
        let pointSize: CGFloat
        switch size {
        case .small:
            pointSize = 8
        case .medium:
            pointSize = 11
        case .large:
            pointSize = 15
        }

        let button = RegionCaptureToolbarSelectableButton(
            image: makeSymbolImage(
                preferredNames: ["circle.fill"],
                accessibilityLabel: size.accessibilityLabel,
                pointSize: pointSize
            ),
            maskCornerRadius: Layout.itemMaskCornerRadius,
            hoverMaskColor: Color.itemHoverMask,
            pressedMaskColor: Color.itemPressedMask,
            selectedMaskColor: Color.itemSelectedMask,
            defaultTintColor: Color.symbol,
            selectedTintColor: Color.accent,
            disabledTintColor: Color.disabledSymbol,
            target: self,
            action: #selector(handleStrokeSize(_:))
        )
        button.imagePosition = .imageOnly
        button.toolTip = size.accessibilityLabel
        button.identifier = NSUserInterfaceItemIdentifier(
            "stroke-size-\(size.accessibilityLabel)"
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(
            equalToConstant: Layout.secondaryButtonSize.width
        ).isActive = true
        button.heightAnchor.constraint(
            equalToConstant: Layout.secondaryButtonSize.height
        ).isActive = true
        return button
    }

    private func makeStrokeColorButton(
        for color: RegionCaptureAnnotationColor
    ) -> RegionCaptureToolbarSelectableButton {
        let button = RegionCaptureToolbarSelectableButton(
            image: nil,
            maskCornerRadius: Layout.itemMaskCornerRadius,
            hoverMaskColor: Color.itemHoverMask,
            pressedMaskColor: Color.itemPressedMask,
            selectedMaskColor: Color.itemSelectedMask,
            defaultTintColor: Color.symbol,
            selectedTintColor: Color.accent,
            disabledTintColor: Color.disabledSymbol,
            target: self,
            action: #selector(handleStrokeColor(_:))
        )
        button.toolTip = color.accessibilityLabel
        button.identifier = NSUserInterfaceItemIdentifier(
            "stroke-color-\(color.accessibilityLabel)"
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(
            equalToConstant: Layout.secondaryButtonSize.width
        ).isActive = true
        button.heightAnchor.constraint(
            equalToConstant: Layout.secondaryButtonSize.height
        ).isActive = true

        let swatch = NSView()
        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = color.overlayColor.cgColor
        swatch.layer?.cornerRadius = Layout.colorSwatchCornerRadius
        swatch.layer?.cornerCurve = .continuous
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
        swatch.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(swatch)
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(
                equalToConstant: Layout.colorSwatchSize
            ),
            swatch.heightAnchor.constraint(
                equalToConstant: Layout.colorSwatchSize
            ),
            swatch.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            swatch.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])

        return button
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
        accessibilityLabel: String,
        pointSize: CGFloat = Layout.symbolPointSize
    ) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
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

    private func applyState() {
        rectangleToolButton.isPersistentSelected = state.isRectangleToolSelected
        ellipseToolButton.isPersistentSelected = state.isEllipseToolSelected
        penToolButton.isPersistentSelected = state.isPenToolSelected
        arrowToolButton.isPersistentSelected = state.isArrowToolSelected
        undoButton.isEnabled = state.canUndo
        undoButton.isPersistentSelected = false
        secondaryBackgroundView.isHidden = !state.showsSecondaryToolbar

        strokeSizeButtons.forEach { size, button in
            button.isPersistentSelected = state.selectedStrokeSize == size
        }
        strokeColorButtons.forEach { color, button in
            button.isPersistentSelected = state.selectedStrokeColor == color
        }

        if
            let currentSelection,
            window?.isVisible == true
        {
            show(for: currentSelection)
        }
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

    @objc
    private func handleRectangleTool() {
        rectangleToolHandler?()
    }

    @objc
    private func handleEllipseTool() {
        ellipseToolHandler?()
    }

    @objc
    private func handlePenTool() {
        penToolHandler?()
    }

    @objc
    private func handleArrowTool() {
        arrowToolHandler?()
    }

    @objc
    private func handleUndo() {
        undoHandler?()
    }

    @objc
    private func handleStrokeSize(_ sender: NSButton) {
        guard
            let pair = strokeSizeButtons.first(where: { $0.1 === sender })
        else {
            return
        }
        strokeSizeHandler?(pair.0)
    }

    @objc
    private func handleStrokeColor(_ sender: NSButton) {
        guard
            let pair = strokeColorButtons.first(where: { $0.1 === sender })
        else {
            return
        }
        strokeColorHandler?(pair.0)
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
        title = ""
        alternateTitle = ""
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

private final class RegionCaptureToolbarSelectableButton: NSButton {

    var isPersistentSelected = false {
        didSet {
            isPressed = false
            syncHoverState()
            updateAppearance()
        }
    }

    override var isEnabled: Bool {
        didSet {
            needsDisplay = true
            syncHoverState()
            updateAppearance()
        }
    }

    private let maskCornerRadius: CGFloat
    private let hoverMaskColor: NSColor
    private let pressedMaskColor: NSColor
    private let selectedMaskColor: NSColor
    private let defaultTintColor: NSColor
    private let selectedTintColor: NSColor
    private let disabledTintColor: NSColor
    private var clearsHoverAfterAction = false
    private var isHovered = false
    private var isPressed = false
    private var requiresPointerExitForHover = false

    init(
        image: NSImage?,
        maskCornerRadius: CGFloat,
        hoverMaskColor: NSColor,
        pressedMaskColor: NSColor,
        selectedMaskColor: NSColor,
        defaultTintColor: NSColor,
        selectedTintColor: NSColor,
        disabledTintColor: NSColor,
        target: AnyObject?,
        action: Selector?
    ) {
        self.maskCornerRadius = maskCornerRadius
        self.hoverMaskColor = hoverMaskColor
        self.pressedMaskColor = pressedMaskColor
        self.selectedMaskColor = selectedMaskColor
        self.defaultTintColor = defaultTintColor
        self.selectedTintColor = selectedTintColor
        self.disabledTintColor = disabledTintColor
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
        title = ""
        alternateTitle = ""
        imageScaling = .scaleProportionallyDown
        setButtonType(.momentaryChange)
        wantsLayer = true
        layer?.cornerRadius = maskCornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.clear.cgColor
        updateAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        guard isEnabled else { return }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        isEnabled
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        super.mouseEntered(with: event)
        syncHoverState()
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        guard isEnabled else { return }
        super.mouseExited(with: event)
        syncHoverState()
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        requiresPointerExitForHover = false
        isPressed = true
        updateAppearance()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isPressed = false
        if clearsHoverAfterAction {
            requiresPointerExitForHover = true
            syncHoverState()
        } else {
            syncHoverState()
        }
        updateAppearance()
    }

    private func syncHoverState() {
        guard
            isEnabled,
            let window
        else {
            isHovered = false
            return
        }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let localPoint = convert(windowPoint, from: nil)
        let isInsideBounds = bounds.contains(localPoint)

        guard requiresPointerExitForHover else {
            isHovered = isInsideBounds
            return
        }

        if isInsideBounds {
            isHovered = false
            return
        }

        requiresPointerExitForHover = false
        isHovered = false
    }

    private func updateAppearance() {
        if !isEnabled {
            layer?.backgroundColor = NSColor.clear.cgColor
            contentTintColor = disabledTintColor
            alphaValue = 1
            return
        }

        if isPersistentSelected {
            layer?.backgroundColor = selectedMaskColor.cgColor
            contentTintColor = selectedTintColor
            alphaValue = 1
            return
        }

        let backgroundColor: NSColor
        if isPressed {
            backgroundColor = pressedMaskColor
        } else if isHovered {
            backgroundColor = hoverMaskColor
        } else {
            backgroundColor = .clear
        }

        layer?.backgroundColor = backgroundColor.cgColor
        contentTintColor = defaultTintColor
    }

    func withHoverClearedAfterAction() -> Self {
        clearsHoverAfterAction = true
        return self
    }
}
