//
//  PetHomeAnchor.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

struct PetHomeAnchor {

    let frame: CGRect
    let visibleFrame: CGRect

    func preferredOrigin(for asset: DesktopPetAsset) -> CGPoint {
        let attachment = asset.layout.attachment
        let petSize = asset.layout.panelSize

        let leftOrigin = CGPoint(
            x: frame.minX - petSize.width + attachment.overlap,
            y: frame.midY - (petSize.height / 2) + attachment.verticalOffset
        )

        if leftOrigin.x >= visibleFrame.minX + attachment.screenPadding {
            return clampedOrigin(
                leftOrigin,
                in: visibleFrame,
                size: petSize,
                screenPadding: attachment.screenPadding
            )
        }

        let rightOrigin = CGPoint(
            x: frame.maxX - attachment.overlap,
            y: frame.midY - (petSize.height / 2) + attachment.verticalOffset
        )

        return clampedOrigin(
            rightOrigin,
            in: visibleFrame,
            size: petSize,
            screenPadding: attachment.screenPadding
        )
    }

    private func clampedOrigin(
        _ origin: CGPoint,
        in visibleFrame: CGRect,
        size: NSSize,
        screenPadding: CGFloat
    ) -> CGPoint {
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
