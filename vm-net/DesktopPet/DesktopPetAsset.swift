//
//  DesktopPetAsset.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

enum DesktopPetAssetID: String, CaseIterable, Identifiable {
    case blobbyCat = "blobby-cat"

    var id: String { rawValue }
}

struct DesktopPetAttachmentLayout {
    let overlap: CGFloat
    let verticalOffset: CGFloat
    let screenPadding: CGFloat
}

struct DesktopPetAmbientOrbit {
    let center: CGPoint
    let centerJitterX: ClosedRange<CGFloat>
    let centerJitterY: ClosedRange<CGFloat>
    let radiusX: ClosedRange<CGFloat>
    let radiusY: ClosedRange<CGFloat>
    let sweep: ClosedRange<CGFloat>
    let pointCount: Int
    let xBounds: ClosedRange<CGFloat>
    let yBounds: ClosedRange<CGFloat>
}

struct DesktopPetBehaviorProfile {
    let movementPadding: CGFloat
    let movementSpeed: ClosedRange<CGFloat>
    let wanderStepDistance: ClosedRange<CGFloat>
    let migrationHeadingJitter: ClosedRange<CGFloat>
    let migrationTargetArrivalThreshold: CGFloat
    let migrationRetargetAfterSegments: ClosedRange<Int>
    let idleDuration: ClosedRange<TimeInterval>
    let restAtHomeDuration: ClosedRange<TimeInterval>
    let wanderCycleBeforeHome: ClosedRange<Int>
    let arrivalThreshold: CGFloat
}

struct DesktopPetViewLayout {
    let panelSize: NSSize
    let backdropSize: NSSize
    let cornerRadius: CGFloat
    let riveInset: NSEdgeInsets
    let interactionInset: NSEdgeInsets
    let pointerCaptureRect: CGRect?
    let previewPadding: NSEdgeInsets
    let attachment: DesktopPetAttachmentLayout
}

struct DesktopPetAsset {
    let id: DesktopPetAssetID
    let displayName: String
    let fileName: String
    let artboardName: String
    let stateMachineName: String?
    let layout: DesktopPetViewLayout
    let behavior: DesktopPetBehaviorProfile
    let ambientOrbit: DesktopPetAmbientOrbit?

    var previewCanvasSize: NSSize {
        NSSize(
            width: layout.panelSize.width + layout.previewPadding.left + layout.previewPadding.right,
            height: layout.panelSize.height + layout.previewPadding.top + layout.previewPadding.bottom
        )
    }

    var previewCenterOffset: CGPoint {
        CGPoint(
            x: (layout.previewPadding.left - layout.previewPadding.right) / 2,
            y: (layout.previewPadding.bottom - layout.previewPadding.top) / 2
        )
    }
}

enum DesktopPetCatalog {
    static let defaultAssetID: DesktopPetAssetID = .blobbyCat

    static func asset(for id: DesktopPetAssetID) -> DesktopPetAsset {
        DesktopPetAsset(
            id: .blobbyCat,
            displayName: "Blobby cat",
            fileName: "blobby-cat",
            artboardName: "Cat Artboard",
            stateMachineName: nil,
            layout: DesktopPetViewLayout(
                panelSize: NSSize(width: 184, height: 184),
                backdropSize: NSSize(width: 128, height: 128),
                cornerRadius: 64,
                riveInset: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
                interactionInset: NSEdgeInsets(top: -10, left: -12, bottom: -8, right: -12),
                pointerCaptureRect: CGRect(x: 0.52, y: 0.56, width: 0.28, height: 0.30),
                previewPadding: NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32),
                attachment: DesktopPetAttachmentLayout(
                    overlap: 46,
                    verticalOffset: 32,
                    screenPadding: 12
                )
            ),
            behavior: DesktopPetBehaviorProfile(
                movementPadding: 44,
                movementSpeed: 88...126,
                wanderStepDistance: 84...168,
                migrationHeadingJitter: (-0.85)...0.85,
                migrationTargetArrivalThreshold: 120,
                migrationRetargetAfterSegments: 4...8,
                idleDuration: 0.9...2.1,
                restAtHomeDuration: 1.4...2.8,
                wanderCycleBeforeHome: 4...7,
                arrivalThreshold: 10
            ),
            ambientOrbit: DesktopPetAmbientOrbit(
                center: CGPoint(x: 0.47, y: 0.80),
                centerJitterX: -0.05...0.05,
                centerJitterY: -0.04...0.04,
                radiusX: 0.18...0.30,
                radiusY: 0.12...0.22,
                sweep: (.pi * 0.55)...(.pi * 1.0),
                pointCount: 6,
                xBounds: 0.16...0.82,
                yBounds: 0.58...0.94
            )
        )
    }
}
