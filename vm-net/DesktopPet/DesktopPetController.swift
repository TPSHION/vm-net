//
//  DesktopPetController.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

@MainActor
final class DesktopPetController: NSWindowController {

    private enum Layout {
        static let panelSize = DesktopPetMetrics.size
        static let overlap: CGFloat = 30
        static let verticalOffset: CGFloat = 18
        static let screenPadding: CGFloat = 12
    }

    private let contentView = DesktopPetContentView(
        frame: NSRect(origin: .zero, size: Layout.panelSize)
    )

    init() {
        let panel = DesktopPetPanel(
            contentRect: NSRect(origin: .zero, size: Layout.panelSize),
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

    func show(
        attachedTo anchorFrame: CGRect,
        on screen: NSScreen?
    ) {
        guard let window else { return }

        window.setFrameOrigin(
            preferredOrigin(
                attachedTo: anchorFrame,
                on: screen,
                size: window.frame.size
            )
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
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .none

        let hostingView = NSView(frame: NSRect(origin: .zero, size: Layout.panelSize))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        contentView.frame = hostingView.bounds
        contentView.translatesAutoresizingMaskIntoConstraints = false
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
        guard let visibleFrame = resolvedVisibleFrame(for: screen) else {
            return CGPoint(
                x: anchorFrame.minX - size.width + Layout.overlap,
                y: anchorFrame.midY - (size.height / 2) + Layout.verticalOffset
            )
        }

        let leftOrigin = CGPoint(
            x: anchorFrame.minX - size.width + Layout.overlap,
            y: anchorFrame.midY - (size.height / 2) + Layout.verticalOffset
        )

        if leftOrigin.x >= visibleFrame.minX + Layout.screenPadding {
            return clampedOrigin(leftOrigin, in: visibleFrame, size: size)
        }

        let rightOrigin = CGPoint(
            x: anchorFrame.maxX - Layout.overlap,
            y: anchorFrame.midY - (size.height / 2) + Layout.verticalOffset
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
        let minX = visibleFrame.minX + Layout.screenPadding
        let maxX = visibleFrame.maxX - size.width - Layout.screenPadding
        let minY = visibleFrame.minY + Layout.screenPadding
        let maxY = visibleFrame.maxY - size.height - Layout.screenPadding

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
