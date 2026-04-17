//
//  PetWorldController.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

@MainActor
final class PetWorldController {

    private let preferences: AppPreferences
    private var asset: DesktopPetAsset
    private var isRoamingEnabled: Bool
    private var overlayController: PetOverlayController?
    private var currentHomeAnchor: PetHomeAnchor?
    private var relativeHomeOffsets: [DesktopPetAssetID: CGPoint] = [:]
    private weak var currentScreen: NSScreen?

    init(
        preferences: AppPreferences,
        asset: DesktopPetAsset,
        isRoamingEnabled: Bool = true
    ) {
        self.preferences = preferences
        self.asset = asset
        self.isRoamingEnabled = isRoamingEnabled
        self.relativeHomeOffsets = Self.loadRelativeHomeOffsets(
            from: preferences
        )
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
            self?.preferences.setDesktopPetRelativeHomeOffset(
                offset,
                for: assetID
            )
        }
        self.overlayController = overlayController
        return overlayController
    }

    private static func loadRelativeHomeOffsets(
        from preferences: AppPreferences
    ) -> [DesktopPetAssetID: CGPoint] {
        Dictionary(
            uniqueKeysWithValues: DesktopPetAssetID.allCases.compactMap { assetID in
                guard let offset = preferences.desktopPetRelativeHomeOffset(
                    for: assetID
                ) else {
                    return nil
                }

                return (assetID, offset)
            }
        )
    }
}
