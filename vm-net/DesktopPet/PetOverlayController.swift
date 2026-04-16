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
        static let floatingBallProtectionPadding: CGFloat = 10
    }

    private let rootView = PetOverlayPassthroughView()
    private let actorController: PetActorController
    private var asset: DesktopPetAsset
    private var isRoamingEnabled: Bool
    private weak var currentScreen: NSScreen?
    private var currentHomeAnchor: PetHomeAnchor?

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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        self.asset = asset
        actorController.applyAsset(asset)
        rootView.frame = CGRect(origin: .zero, size: asset.layout.panelSize)
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

        let shouldProtectFloatingBall =
            currentHomeAnchor?
            .frame
            .insetBy(
                dx: -Input.floatingBallProtectionPadding,
                dy: -Input.floatingBallProtectionPadding
            )
            .intersects(petFrame) == true

        panel.ignoresMouseEvents = shouldProtectFloatingBall
    }
}

private final class PetOverlayPanel: NSPanel {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class PetOverlayPassthroughView: NSView {

    weak var actorView: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let actorView else { return nil }
        let pointInActor = convert(point, to: actorView)
        return actorView.hitTest(pointInActor)
    }
}
