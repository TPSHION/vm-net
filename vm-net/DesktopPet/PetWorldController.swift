//
//  PetWorldController.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

@MainActor
final class PetWorldController {

    private var asset: DesktopPetAsset
    private var overlayController: PetOverlayController?
    private var currentHomeAnchor: PetHomeAnchor?
    private weak var currentScreen: NSScreen?

    init(asset: DesktopPetAsset) {
        self.asset = asset
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        self.asset = asset
        overlayController?.applyAsset(asset)

        if let currentScreen, let currentHomeAnchor {
            overlayController?.show(on: currentScreen, homeAnchor: currentHomeAnchor)
        }
    }

    func show(
        homeAnchorFrame: CGRect,
        on screen: NSScreen?
    ) {
        guard
            let resolvedScreen = screen
                ?? NSScreen.main
                ?? NSScreen.screens.first
        else {
            return
        }

        currentScreen = resolvedScreen
        currentHomeAnchor = PetHomeAnchor(
            frame: homeAnchorFrame,
            visibleFrame: resolvedScreen.visibleFrame
        )

        let overlayController = ensureOverlayController()
        overlayController.applyAsset(asset)
        overlayController.show(
            on: resolvedScreen,
            homeAnchor: currentHomeAnchor
        )
    }

    func hide() {
        overlayController?.hide()
    }

    private func ensureOverlayController() -> PetOverlayController {
        if let overlayController {
            return overlayController
        }

        let overlayController = PetOverlayController(asset: asset)
        self.overlayController = overlayController
        return overlayController
    }
}
