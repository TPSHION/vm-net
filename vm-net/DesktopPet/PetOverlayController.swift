//
//  PetOverlayController.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

@MainActor
final class PetOverlayController: NSWindowController {

    private enum Input {
    }

    private let rootView = PetOverlayPassthroughView()
    private let actorController: PetActorController
    private var asset: DesktopPetAsset
    private var isRoamingEnabled: Bool
    private weak var currentScreen: NSScreen?
    private var currentHomeAnchor: PetHomeAnchor?
    var relativeHomeOffsetDidChange: ((DesktopPetAssetID, CGPoint) -> Void)?

    init(
        asset: DesktopPetAsset,
        isRoamingEnabled: Bool = true
    ) {
        self.asset = asset
        self.isRoamingEnabled = isRoamingEnabled
        self.actorController = PetActorController(
            asset: asset,
            isRoamingEnabled: isRoamingEnabled
        )

        let panel = PetOverlayPanel(
            contentRect: NSRect(origin: .zero, size: asset.layout.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        configurePanel(panel)
        actorController.attach(to: rootView)
        actorController.originDidChange = { [weak self] origin in
            guard let self, let window = self.window else { return }
            window.setFrameOrigin(origin)
            self.updateInputPassthrough(for: window.frame)
        }
        actorController.viewDidChange = { [weak self] view in
            self?.rootView.actorView = view
        }
        rootView.actorView = actorController.view
        rootView.dragCaptureRect = dragCaptureRect(for: asset)
        rootView.dragDidBegin = { [weak self] in
            self?.actorController.beginManualDrag()
        }
        rootView.dragDidMove = { [weak self] origin in
            self?.actorController.updateDraggedOrigin(origin)
        }
        rootView.dragDidEnd = { [weak self] origin in
            self?.completeManualDrag(at: origin)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        self.asset = asset
        actorController.applyAsset(asset)
        rootView.frame = CGRect(origin: .zero, size: asset.layout.panelSize)
        rootView.dragCaptureRect = dragCaptureRect(for: asset)
        window?.setContentSize(asset.layout.panelSize)
        if let currentScreen {
            actorController.updateEnvironment(
                movementBounds: movementBounds(for: currentScreen),
                homeOrigin: currentHomeAnchor?.preferredOrigin(for: asset)
            )
        }
    }

    func setRoamingEnabled(_ isEnabled: Bool) {
        isRoamingEnabled = isEnabled
        actorController.setRoamingEnabled(isEnabled)
    }

    func show(on screen: NSScreen, homeAnchor: PetHomeAnchor?) {
        currentScreen = screen
        currentHomeAnchor = homeAnchor

        guard let window else { return }

        rootView.frame = CGRect(origin: .zero, size: asset.layout.panelSize)
        rootView.dragCaptureRect = dragCaptureRect(for: asset)
        window.setContentSize(asset.layout.panelSize)

        actorController.updateEnvironment(
            movementBounds: movementBounds(for: screen),
            homeOrigin: homeAnchor?.preferredOrigin(for: asset)
        )
        actorController.start()
        updateInputPassthrough(for: window.frame)

        if !window.isVisible {
            showWindow(nil)
        }

        window.orderFrontRegardless()
    }

    func hide() {
        actorController.stop()
        window?.orderOut(nil)
    }

    private func configurePanel(_ panel: PetOverlayPanel) {
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // Keep the roaming pet above regular app content, but below the
        // floating capsule so the capsule can still be freely dragged.
        panel.level = NSWindow.Level(
            rawValue: NSWindow.Level.floating.rawValue - 1
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .none

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.frame = CGRect(origin: .zero, size: asset.layout.panelSize)
        panel.contentView = rootView
    }

    private func movementBounds(for screen: NSScreen) -> CGRect {
        let safeVisibleFrame = screen.visibleFrame.insetBy(
            dx: asset.behavior.movementPadding,
            dy: asset.behavior.movementPadding
        )

        return CGRect(
            x: safeVisibleFrame.minX,
            y: safeVisibleFrame.minY,
            width: max(safeVisibleFrame.width - asset.layout.panelSize.width, 1),
            height: max(safeVisibleFrame.height - asset.layout.panelSize.height, 1)
        )
    }

    private func updateInputPassthrough(for petFrame: CGRect) {
        guard let panel = window as? PetOverlayPanel else { return }
        panel.ignoresMouseEvents = false
    }

    private func completeManualDrag(at origin: CGPoint) {
        defer {
            actorController.endManualDrag()
        }

        guard
            !isRoamingEnabled,
            let currentScreen,
            let currentHomeAnchor
        else {
            return
        }

        let clampedOrigin = clampedWindowOrigin(
            origin,
            visibleFrame: currentScreen.visibleFrame
        )
        let relativeOriginOffset = CGPoint(
            x: clampedOrigin.x - currentHomeAnchor.frame.origin.x,
            y: clampedOrigin.y - currentHomeAnchor.frame.origin.y
        )
        let updatedHomeAnchor = PetHomeAnchor(
            frame: currentHomeAnchor.frame,
            visibleFrame: currentHomeAnchor.visibleFrame,
            relativeOriginOffset: relativeOriginOffset
        )

        self.currentHomeAnchor = updatedHomeAnchor
        relativeHomeOffsetDidChange?(asset.id, relativeOriginOffset)
        actorController.updateEnvironment(
            movementBounds: movementBounds(for: currentScreen),
            homeOrigin: updatedHomeAnchor.preferredOrigin(for: asset)
        )
    }

    private func dragCaptureRect(for asset: DesktopPetAsset) -> CGRect {
        let bounds = CGRect(origin: .zero, size: asset.layout.panelSize)
        let inset = asset.layout.riveInset
        let captureRect = CGRect(
            x: bounds.minX + inset.left,
            y: bounds.minY + inset.bottom,
            width: bounds.width - inset.left - inset.right,
            height: bounds.height - inset.top - inset.bottom
        )

        guard captureRect.width > 0, captureRect.height > 0 else {
            return bounds
        }

        return captureRect
    }

    private func clampedWindowOrigin(
        _ origin: CGPoint,
        visibleFrame: CGRect
    ) -> CGPoint {
        let screenPadding = asset.layout.attachment.screenPadding
        let minX = visibleFrame.minX + screenPadding
        let maxX = visibleFrame.maxX - asset.layout.panelSize.width - screenPadding
        let minY = visibleFrame.minY + screenPadding
        let maxY = visibleFrame.maxY - asset.layout.panelSize.height - screenPadding

        return CGPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }
}

private final class PetOverlayPanel: NSPanel {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class PetOverlayPassthroughView: NSView {

    weak var actorView: NSView?
    var dragCaptureRect: CGRect = .zero {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }
    var dragDidBegin: (() -> Void)?
    var dragDidMove: ((CGPoint) -> Void)?
    var dragDidEnd: ((CGPoint) -> Void)?
    private var dragOffsetInWindow: CGPoint?
    private var trackingArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard actorView != nil else { return nil }

        if dragOffsetInWindow != nil {
            return self
        }

        return dragCaptureRect.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragOffsetInWindow = event.locationInWindow
        NSCursor.closedHand.push()
        dragDidBegin?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let window,
            let dragOffsetInWindow
        else {
            return
        }

        let mouseInScreen = window.convertPoint(toScreen: event.locationInWindow)
        let origin = CGPoint(
            x: mouseInScreen.x - dragOffsetInWindow.x,
            y: mouseInScreen.y - dragOffsetInWindow.y
        )
        dragDidMove?(origin)
    }

    override func mouseUp(with event: NSEvent) {
        guard dragOffsetInWindow != nil else { return }

        dragOffsetInWindow = nil
        NSCursor.pop()
        updateCursor(for: convert(event.locationInWindow, from: nil))
        dragDidEnd?(window?.frame.origin ?? .zero)
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        guard dragOffsetInWindow == nil else { return }
        NSCursor.arrow.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    private func updateCursor(for point: CGPoint) {
        guard dragOffsetInWindow == nil else {
            NSCursor.closedHand.set()
            return
        }

        if dragCaptureRect.contains(point) {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}
