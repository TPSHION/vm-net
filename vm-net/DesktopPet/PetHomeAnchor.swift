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
    let relativeOriginOffset: CGPoint?

    func preferredOrigin(for asset: DesktopPetAsset) -> CGPoint {
        if let relativeOriginOffset {
            return clampedOrigin(
                CGPoint(
                    x: frame.origin.x + relativeOriginOffset.x,
                    y: frame.origin.y + relativeOriginOffset.y
                ),
                in: visibleFrame,
                size: asset.layout.panelSize,
                screenPadding: asset.layout.attachment.screenPadding
            )
        }

        return clampedPreferredOrigin(for: asset)
    }

    func resolvedRelativeOriginOffset(for asset: DesktopPetAsset) -> CGPoint {
        let rawOrigin = clampedPreferredOrigin(for: asset)
        return CGPoint(
            x: rawOrigin.x - frame.origin.x,
            y: rawOrigin.y - frame.origin.y
        )
    }

    private func clampedPreferredOrigin(for asset: DesktopPetAsset) -> CGPoint {
        let attachment = asset.layout.attachment
        return clampedOrigin(
            selectedRawOrigin(for: asset),
            in: visibleFrame,
            size: asset.layout.panelSize,
            screenPadding: attachment.screenPadding
        )
    }

    private func selectedRawOrigin(for asset: DesktopPetAsset) -> CGPoint {
        let attachment = asset.layout.attachment
        let petSize = asset.layout.panelSize

        let leftOrigin = CGPoint(
            x: frame.minX - petSize.width + attachment.overlap + attachment.horizontalOffset,
            y: frame.midY - (petSize.height / 2) + attachment.verticalOffset
        )
        let leftFits = leftOrigin.x >= visibleFrame.minX + attachment.screenPadding

        let rightOrigin = CGPoint(
            x: frame.maxX - attachment.overlap + attachment.horizontalOffset,
            y: frame.midY - (petSize.height / 2) + attachment.verticalOffset
        )
        let rightFits = rightOrigin.x <= visibleFrame.maxX - petSize.width - attachment.screenPadding

        switch attachment.preferredSide {
        case .left:
            return leftFits ? leftOrigin : rightOrigin
        case .right:
            return rightFits ? rightOrigin : leftOrigin
        case .automatic:
            return leftFits ? leftOrigin : rightOrigin
        }
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
