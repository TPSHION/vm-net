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
    private var isRoamingEnabled: Bool
    private var overlayController: PetOverlayController?
    private var currentHomeAnchor: PetHomeAnchor?
    private var relativeHomeOffsets: [DesktopPetAssetID: CGPoint] = [:]
    private weak var currentScreen: NSScreen?

    init(
        asset: DesktopPetAsset,
        isRoamingEnabled: Bool = true
    ) {
        self.asset = asset
        self.isRoamingEnabled = isRoamingEnabled
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        self.asset = asset
        overlayController?.applyAsset(asset)

        if let currentHomeAnchor, relativeHomeOffsets[asset.id] == nil {
            relativeHomeOffsets[asset.id] = currentHomeAnchor.resolvedRelativeOriginOffset(for: asset)
        }

        if let currentScreen, let currentHomeAnchor {
            let updatedHomeAnchor = PetHomeAnchor(
                frame: currentHomeAnchor.frame,
                visibleFrame: currentHomeAnchor.visibleFrame,
                relativeOriginOffset: relativeHomeOffsets[asset.id]
            )
            self.currentHomeAnchor = updatedHomeAnchor
            overlayController?.show(on: currentScreen, homeAnchor: updatedHomeAnchor)
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
        let relativeOriginOffset = relativeHomeOffsets[asset.id]
            ?? PetHomeAnchor(
                frame: homeAnchorFrame,
                visibleFrame: resolvedScreen.visibleFrame,
                relativeOriginOffset: nil
            ).resolvedRelativeOriginOffset(for: asset)

        relativeHomeOffsets[asset.id] = relativeOriginOffset

        currentHomeAnchor = PetHomeAnchor(
            frame: homeAnchorFrame,
            visibleFrame: resolvedScreen.visibleFrame,
            relativeOriginOffset: relativeOriginOffset
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

    func setRoamingEnabled(_ isEnabled: Bool) {
        isRoamingEnabled = isEnabled
        overlayController?.setRoamingEnabled(isEnabled)
    }

    private func ensureOverlayController() -> PetOverlayController {
        if let overlayController {
            return overlayController
        }

        let overlayController = PetOverlayController(
            asset: asset,
            isRoamingEnabled: isRoamingEnabled
        )
        overlayController.relativeHomeOffsetDidChange = { [weak self] assetID, offset in
            self?.relativeHomeOffsets[assetID] = offset
        }
        self.overlayController = overlayController
        return overlayController
    }
}
