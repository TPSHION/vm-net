//
//  DesktopPetController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

@MainActor
final class DesktopPetController: NSWindowController {

    private let hostingView: DesktopPetPassthroughView
    private let contentView: DesktopPetContentView
    private var asset: DesktopPetAsset
    private var lastAnchorFrame: CGRect?
    private weak var lastScreen: NSScreen?

    init(asset: DesktopPetAsset) {
        self.asset = asset
        self.hostingView = DesktopPetPassthroughView(
            frame: NSRect(origin: .zero, size: asset.layout.panelSize)
        )
        self.contentView = DesktopPetContentView(
            frame: NSRect(origin: .zero, size: asset.layout.panelSize),
            asset: asset
        )

        let panel = DesktopPetPanel(
            contentRect: NSRect(origin: .zero, size: asset.layout.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        configurePanel(panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        guard self.asset.id != asset.id else { return }

        self.asset = asset
        contentView.applyAsset(asset)
        hostingView.frame = NSRect(origin: .zero, size: asset.layout.panelSize)

        guard let window else { return }

        let isVisible = window.isVisible
        let newFrame = NSRect(
            origin: window.frame.origin,
            size: asset.layout.panelSize
        )
        window.setFrame(newFrame, display: false)

        if let lastAnchorFrame {
            window.setFrameOrigin(
                preferredOrigin(
                    attachedTo: lastAnchorFrame,
                    on: lastScreen,
                    size: asset.layout.panelSize
                )
            )
        } else if isVisible {
            window.orderFrontRegardless()
        }
    }

    func show(
        attachedTo anchorFrame: CGRect,
        on screen: NSScreen?
    ) {
        guard let window else { return }

        lastAnchorFrame = anchorFrame
        lastScreen = screen

        let targetSize = asset.layout.panelSize
        window.setFrame(
            NSRect(
                origin: preferredOrigin(
                    attachedTo: anchorFrame,
                    on: screen,
                    size: targetSize
                ),
                size: targetSize
            ),
            display: false
        )

        if !window.isVisible {
            showWindow(nil)
        }

        window.orderFrontRegardless()
        contentView.setAmbientInteractionEnabled(true)
    }

    func hide() {
        contentView.setAmbientInteractionEnabled(false)
        window?.orderOut(nil)
    }

    private func configurePanel(_ panel: DesktopPetPanel) {
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .none

        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        contentView.frame = hostingView.bounds
        contentView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.targetView = contentView
        hostingView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: hostingView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: hostingView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: hostingView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: hostingView.bottomAnchor),
        ])

        panel.contentView = hostingView
    }

    private func preferredOrigin(
        attachedTo anchorFrame: CGRect,
        on screen: NSScreen?,
        size: NSSize
    ) -> CGPoint {
        let attachment = asset.layout.attachment

        guard let visibleFrame = resolvedVisibleFrame(for: screen) else {
            return CGPoint(
                x: anchorFrame.minX - size.width + attachment.overlap,
                y: anchorFrame.midY - (size.height / 2) + attachment.verticalOffset
            )
        }

        let leftOrigin = CGPoint(
            x: anchorFrame.minX - size.width + attachment.overlap,
            y: anchorFrame.midY - (size.height / 2) + attachment.verticalOffset
        )

        if leftOrigin.x >= visibleFrame.minX + attachment.screenPadding {
            return clampedOrigin(leftOrigin, in: visibleFrame, size: size)
        }

        let rightOrigin = CGPoint(
            x: anchorFrame.maxX - attachment.overlap,
            y: anchorFrame.midY - (size.height / 2) + attachment.verticalOffset
        )
        return clampedOrigin(rightOrigin, in: visibleFrame, size: size)
    }

    private func resolvedVisibleFrame(for screen: NSScreen?) -> CGRect? {
        screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
    }

    private func clampedOrigin(
        _ origin: CGPoint,
        in visibleFrame: CGRect,
        size: NSSize
    ) -> CGPoint {
        let screenPadding = asset.layout.attachment.screenPadding
        let minX = visibleFrame.minX + screenPadding
        let maxX = visibleFrame.maxX - size.width - screenPadding
        let minY = visibleFrame.minY + screenPadding
        let maxY = visibleFrame.maxY - size.height - screenPadding

        return CGPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }
}

private final class DesktopPetPanel: NSPanel {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class DesktopPetPassthroughView: NSView {

    weak var targetView: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let targetView else { return nil }
        let pointInTarget = convert(point, to: targetView)
        return targetView.hitTest(pointInTarget)
    }
}
