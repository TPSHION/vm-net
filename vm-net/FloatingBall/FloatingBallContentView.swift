//
//  FloatingBallContentView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

final class FloatingBallContentView: NSView {

    static let capsuleSize = NSSize(width: 88, height: 46)
    static let capsuleCornerRadius: CGFloat = 16
    static let contentHorizontalPadding: CGFloat = 8
    static let contentVerticalPadding: CGFloat = 6
    static let contentRowSpacing: CGFloat = 3
    static let contentItemSpacing: CGFloat = 6
    static let symbolFontSize: CGFloat = 9.5
    static let valueFontSize: CGFloat = 9.5

    private enum Layout {
        static let size = FloatingBallContentView.capsuleSize
        static let horizontalPadding = FloatingBallContentView.contentHorizontalPadding
        static let verticalPadding = FloatingBallContentView.contentVerticalPadding
        static let rowSpacing = FloatingBallContentView.contentRowSpacing
        static let cornerRadius = FloatingBallContentView.capsuleCornerRadius
        static let iconWidth: CGFloat = 9
    }

    private struct ResolvedAppearance {
        let fillColor: NSColor
        let borderColor: NSColor
        let textColor: NSColor
    }

    private let contentStack = NSStackView()
    private let uploadRow = NSStackView()
    private let downloadRow = NSStackView()
    private let capsuleView = NSView()
    private let materialView = NSVisualEffectView()
    private let uploadIcon = NSTextField(labelWithString: "↑")
    private let downloadIcon = NSTextField(labelWithString: "↓")
    private let uploadLabel = NSTextField(labelWithString: "0B/s")
    private let downloadLabel = NSTextField(labelWithString: "0B/s")
    private let backgroundFillLayer = CALayer()
    private var mouseDownScreenLocation: NSPoint?
    private var didDrag = false

    var openHandler: (() -> Void)?

    override var intrinsicContentSize: NSSize {
        Layout.size
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateGradientFrames()
    }

    func applyAppearance(
        backgroundColor: NSColor,
        textColor: NSColor,
        backgroundTransparency: Double
    ) {
        let appearance = resolveAppearance(
            backgroundColor: backgroundColor,
            textColor: textColor,
            backgroundTransparency: backgroundTransparency
        )

        backgroundFillLayer.backgroundColor = appearance.fillColor.cgColor
        capsuleView.layer?.borderColor = appearance.borderColor.cgColor
        uploadLabel.textColor = appearance.textColor
        downloadLabel.textColor = appearance.textColor
        uploadIcon.textColor = appearance.textColor
        downloadIcon.textColor = appearance.textColor
    }

    func render(
        uploadText: String,
        downloadText: String
    ) {
        uploadLabel.stringValue = uploadText
        downloadLabel.stringValue = downloadText
        uploadLabel.alphaValue = 1
        downloadLabel.alphaValue = 1
        uploadIcon.alphaValue = 1
        downloadIcon.alphaValue = 1
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownScreenLocation = NSEvent.mouseLocation
        didDrag = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownScreenLocation else {
            super.mouseDragged(with: event)
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let distance = hypot(
            currentLocation.x - mouseDownScreenLocation.x,
            currentLocation.y - mouseDownScreenLocation.y
        )

        if distance >= 3 {
            didDrag = true
        }

        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard event.buttonNumber == 0 else {
            super.mouseUp(with: event)
            return
        }

        defer {
            mouseDownScreenLocation = nil
            didDrag = false
        }

        guard !didDrag else { return }

        openHandler?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu else {
            super.rightMouseDown(with: event)
            return
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.wantsLayer = true
        capsuleView.layer?.cornerRadius = Layout.cornerRadius
        capsuleView.layer?.masksToBounds = true
        capsuleView.layer?.borderWidth = 0.7
        capsuleView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08)
            .cgColor
        capsuleView.layer?.backgroundColor = NSColor.clear.cgColor

        materialView.translatesAutoresizingMaskIntoConstraints = false
        materialView.material = .hudWindow
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.backgroundColor = NSColor.clear.cgColor
        materialView.alphaValue = 0

        addSubview(capsuleView)
        capsuleView.addSubview(materialView)
        configureBackgroundLayers()

        configureIcon(uploadIcon)
        configureIcon(downloadIcon)

        [uploadLabel, downloadLabel].forEach { label in
            label.font = .monospacedSystemFont(
                ofSize: Self.valueFontSize,
                weight: .semibold
            )
            label.textColor = .white
            label.alignment = .right
            label.lineBreakMode = .byClipping
            label.setContentCompressionResistancePriority(
                .required,
                for: .horizontal
            )
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        configureRow(uploadRow, iconLabel: uploadIcon, valueLabel: uploadLabel)
        configureRow(downloadRow, iconLabel: downloadIcon, valueLabel: downloadLabel)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.distribution = .fillEqually
        contentStack.spacing = Layout.rowSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(uploadRow)
        contentStack.addArrangedSubview(downloadRow)

        capsuleView.addSubview(contentStack)
        applyAppearance(
            backgroundColor: .black,
            textColor: .white,
            backgroundTransparency: 0.08
        )

        NSLayoutConstraint.activate([
            capsuleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            capsuleView.topAnchor.constraint(equalTo: topAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: bottomAnchor),

            materialView.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor),
            materialView.topAnchor.constraint(equalTo: capsuleView.topAnchor),
            materialView.bottomAnchor.constraint(equalTo: capsuleView.bottomAnchor),

            contentStack.leadingAnchor.constraint(
                equalTo: capsuleView.leadingAnchor,
                constant: Layout.horizontalPadding
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: capsuleView.trailingAnchor,
                constant: -Layout.horizontalPadding
            ),
            contentStack.topAnchor.constraint(
                equalTo: capsuleView.topAnchor,
                constant: Layout.verticalPadding
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: capsuleView.bottomAnchor,
                constant: -Layout.verticalPadding
            ),
        ])
    }

    private func configureBackgroundLayers() {
        capsuleView.layer?.insertSublayer(backgroundFillLayer, above: materialView.layer)
    }

    private func updateGradientFrames() {
        backgroundFillLayer.frame = capsuleView.bounds
    }

    private func configureRow(
        _ row: NSStackView,
        iconLabel: NSTextField,
        valueLabel: NSTextField
    ) {
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = Self.contentItemSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(iconLabel)
        row.addArrangedSubview(valueLabel)
    }

    private func configureIcon(_ iconLabel: NSTextField) {
        iconLabel.font = .systemFont(ofSize: Self.symbolFontSize, weight: .bold)
        iconLabel.textColor = .white
        iconLabel.alignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.setContentHuggingPriority(.required, for: .horizontal)
        iconLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            iconLabel.widthAnchor.constraint(equalToConstant: Layout.iconWidth),
        ])
    }

    private func resolveAppearance(
        backgroundColor: NSColor,
        textColor: NSColor,
        backgroundTransparency: Double
    ) -> ResolvedAppearance {
        let clampedTransparency = max(0, min(0.6, CGFloat(backgroundTransparency)))
        let resolvedBackground = backgroundColor.usingColorSpace(.deviceRGB) ?? backgroundColor
        let resolvedText = textColor.usingColorSpace(.deviceRGB) ?? textColor
        let fillAlpha = max(0.4, 1 - clampedTransparency)
        let borderAlpha = 0.12 - (clampedTransparency * 0.05)

        return ResolvedAppearance(
            fillColor: resolvedBackground.withAlphaComponent(fillAlpha),
            borderColor: NSColor.white.withAlphaComponent(borderAlpha),
            textColor: resolvedText
        )
    }
}
