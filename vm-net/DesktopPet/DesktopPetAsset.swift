//
//  DesktopPetAsset.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

enum DesktopPetAssetID: String, CaseIterable, Identifiable {
    case blobbyCat = "blobby-cat"
    case catPlayingAnimation = "cat-playing-animation"

    var id: String { rawValue }
}

enum PetDefinitionID: String, CaseIterable, Identifiable {
    case blobbyCat = "blobby-cat"
    case catPlayingAnimation = "cat-playing-animation"

    var id: String { rawValue }
}

enum PetRenderBackend: String, CaseIterable, Identifiable {
    case rive
    case sceneKit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rive:
            return "Rive"
        case .sceneKit:
            return "SceneKit"
        }
    }
}

enum PetAbility: String, CaseIterable, Identifiable, Hashable {
    case roaming
    case interactiveBall
    case homeReturn
    case throughputReactive
    case multiScreen
    case advancedInteraction

    var id: String { rawValue }
}

struct PetAnimationClipHints {
    let preferredKeywords: [String]
    let fallbackKeywords: [String]

    init(
        preferredKeywords: [String],
        fallbackKeywords: [String] = []
    ) {
        self.preferredKeywords = preferredKeywords
        self.fallbackKeywords = fallbackKeywords
    }
}

struct PetAnimationProfile {
    let idle: PetAnimationClipHints
    let wander: PetAnimationClipHints
    let goHome: PetAnimationClipHints
    let restAtHome: PetAnimationClipHints
    let interact: PetAnimationClipHints?
}

struct PetDefinition: Identifiable {
    let id: PetDefinitionID
    let displayName: String
    let renderBackend: PetRenderBackend
    let assetPath: String
    let animationProfile: PetAnimationProfile
    let defaultScale: CGFloat
    let defaultBehaviorProfile: DesktopPetBehaviorProfile
    let supportedAbilities: Set<PetAbility>
    let sourcePackName: String
    let sourceURL: String
    let isRuntimeReady: Bool
}

struct DesktopPetAttachmentLayout {
    enum Side {
        case left
        case right
        case automatic
    }

    let preferredSide: Side
    let overlap: CGFloat
    let horizontalOffset: CGFloat
    let verticalOffset: CGFloat
    let screenPadding: CGFloat
}

struct DesktopPetAmbientOrbit {
    let bodyCenter: CGPoint
    let centerJitterX: ClosedRange<CGFloat>
    let centerJitterY: ClosedRange<CGFloat>
    let bodyHalfWidth: CGFloat
    let bodyHalfHeight: CGFloat
    let leadPadding: CGFloat
    let leadDistanceMultiplier: CGFloat
    let radiusX: ClosedRange<CGFloat>
    let radiusY: ClosedRange<CGFloat>
    let pointCount: Int
    let xBounds: ClosedRange<CGFloat>
    let yBounds: ClosedRange<CGFloat>
}

enum DesktopPetRiveInteractionMode {
    case none
    case ballGuide
}

struct DesktopPetRiveBehavior {
    let interactionMode: DesktopPetRiveInteractionMode
    let ambientOrbit: DesktopPetAmbientOrbit?
    let movementGuideLeadDelay: TimeInterval
    let allowsAmbientAutoInteraction: Bool
    let allowsDirectPointerInteraction: Bool

    var allowsMovementGuide: Bool {
        interactionMode == .ballGuide
            && ambientOrbit != nil
            && allowsAmbientAutoInteraction
    }

    var supportsAnyInteraction: Bool {
        allowsMovementGuide || allowsDirectPointerInteraction
    }
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
    let artboardName: String?
    let stateMachineName: String?
    let layout: DesktopPetViewLayout
    let behavior: DesktopPetBehaviorProfile
    let riveBehavior: DesktopPetRiveBehavior?

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
    static let defaultAssetID: DesktopPetAssetID = .catPlayingAnimation

    static func asset(for id: DesktopPetAssetID) -> DesktopPetAsset {
        switch id {
        case .blobbyCat:
            return DesktopPetAsset(
                id: .blobbyCat,
                displayName: "Blobby cat",
                fileName: "blobby-cat",
                artboardName: "Cat Artboard",
                stateMachineName: nil,
                layout: blobbyCatLayout,
                behavior: defaultBehavior,
                riveBehavior: DesktopPetRiveBehavior(
                    interactionMode: .ballGuide,
                    ambientOrbit: DesktopPetAmbientOrbit(
                        bodyCenter: CGPoint(x: 0.40, y: 0.48),
                        centerJitterX: -0.03...0.03,
                        centerJitterY: -0.03...0.03,
                        bodyHalfWidth: 0.28,
                        bodyHalfHeight: 0.30,
                        leadPadding: 0.16,
                        leadDistanceMultiplier: 4.0,
                        radiusX: 0.18...0.30,
                        radiusY: 0.12...0.22,
                        pointCount: 6,
                        xBounds: 0.08...0.92,
                        yBounds: 0.54...0.96
                    ),
                    movementGuideLeadDelay: 0.42,
                    allowsAmbientAutoInteraction: true,
                    allowsDirectPointerInteraction: true
                )
            )
        case .catPlayingAnimation:
            return DesktopPetAsset(
                id: .catPlayingAnimation,
                displayName: "Cat Playing",
                fileName: "cat-playing-animation",
                artboardName: nil,
                stateMachineName: nil,
                layout: catPlayingLayout,
                behavior: defaultBehavior,
                riveBehavior: DesktopPetRiveBehavior(
                    interactionMode: .none,
                    ambientOrbit: nil,
                    movementGuideLeadDelay: 0,
                    allowsAmbientAutoInteraction: false,
                    allowsDirectPointerInteraction: false
                )
            )
        }
    }
}

enum PetDefinitionCatalog {

    static var defaultDefinitionID: PetDefinitionID { .catPlayingAnimation }

    static var runtimeDefinitions: [PetDefinition] {
        [
            PetDefinition(
                id: .blobbyCat,
                displayName: "Blobby cat",
                renderBackend: .rive,
                assetPath: "vm-net/Resources/DesktopPet/default/blobby-cat.riv",
                animationProfile: PetAnimationProfile(
                    idle: PetAnimationClipHints(
                        preferredKeywords: ["idle", "rest", "default"]
                    ),
                    wander: PetAnimationClipHints(
                        preferredKeywords: ["wander", "move", "walk"],
                        fallbackKeywords: ["idle"]
                    ),
                    goHome: PetAnimationClipHints(
                        preferredKeywords: ["move", "walk", "return"],
                        fallbackKeywords: ["wander", "idle"]
                    ),
                    restAtHome: PetAnimationClipHints(
                        preferredKeywords: ["rest", "idle", "sleep"]
                    ),
                    interact: PetAnimationClipHints(
                        preferredKeywords: ["ball", "play", "interact"]
                    )
                ),
                defaultScale: 1.0,
                defaultBehaviorProfile: DesktopPetCatalog.defaultAsset.behavior,
                supportedAbilities: [.roaming, .interactiveBall, .homeReturn],
                sourcePackName: "Rive Marketplace",
                sourceURL: "https://www.rive.app/marketplace/2992-6574-blobby-cat/",
                isRuntimeReady: true
            ),
            PetDefinition(
                id: .catPlayingAnimation,
                displayName: "Cat Playing",
                renderBackend: .rive,
                assetPath: "vm-net/Resources/DesktopPet/default/cat-playing-animation.riv",
                animationProfile: PetAnimationProfile(
                    idle: PetAnimationClipHints(
                        preferredKeywords: ["idle", "default", "rest"]
                    ),
                    wander: PetAnimationClipHints(
                        preferredKeywords: ["move", "walk", "follow"],
                        fallbackKeywords: ["idle"]
                    ),
                    goHome: PetAnimationClipHints(
                        preferredKeywords: ["move", "walk", "follow"],
                        fallbackKeywords: ["idle"]
                    ),
                    restAtHome: PetAnimationClipHints(
                        preferredKeywords: ["idle", "rest", "default"]
                    ),
                    interact: nil
                ),
                defaultScale: 1.0,
                defaultBehaviorProfile: DesktopPetCatalog.defaultAsset.behavior,
                supportedAbilities: [.roaming, .homeReturn],
                sourcePackName: "Local Rive Resource",
                sourceURL: "/Users/chen/cwork/vm-net/rive-resource/cat_playing_animation.riv",
                isRuntimeReady: true
            )
        ]
    }

    static var prototypeDefinitions: [PetDefinition] {
        []
    }

    static var allDefinitions: [PetDefinition] {
        runtimeDefinitions + prototypeDefinitions
    }

    static func definition(for id: PetDefinitionID) -> PetDefinition {
        allDefinitions.first(where: { $0.id == id })
            ?? runtimeDefinitions[0]
    }

    static func definition(for asset: DesktopPetAsset) -> PetDefinition {
        definition(for: PetDefinitionID(rawValue: asset.id.rawValue) ?? defaultDefinitionID)
    }
}

private extension DesktopPetCatalog {

    static var defaultAsset: DesktopPetAsset {
        asset(for: defaultAssetID)
    }

    static var defaultBehavior: DesktopPetBehaviorProfile {
        DesktopPetBehaviorProfile(
            movementPadding: 44,
            movementSpeed: 88...126,
            wanderStepDistance: 84...168,
            migrationHeadingJitter: (-0.85)...0.85,
            migrationTargetArrivalThreshold: 120,
            migrationRetargetAfterSegments: 4...8,
            idleDuration: 0.9...2.1,
            restAtHomeDuration: 1.4...3.2,
            wanderCycleBeforeHome: 4...7,
            arrivalThreshold: 10
        )
    }

    static var blobbyCatLayout: DesktopPetViewLayout {
        makeRiveLayout(
            attachment: DesktopPetAttachmentLayout(
                preferredSide: .left,
                overlap: 46,
                horizontalOffset: 0,
                verticalOffset: 32,
                screenPadding: 12
            )
        )
    }

    static var catPlayingLayout: DesktopPetViewLayout {
        makeRiveLayout(
            attachment: DesktopPetAttachmentLayout(
                preferredSide: .left,
                overlap: 46,
                horizontalOffset: 70,
                verticalOffset: 46,
                screenPadding: 12
            )
        )
    }

    private static func makeRiveLayout(
        attachment: DesktopPetAttachmentLayout,
        panelSize: NSSize = NSSize(width: 184, height: 184),
        backdropSize: NSSize = NSSize(width: 128, height: 128),
        cornerRadius: CGFloat = 64,
        riveInset: NSEdgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
        interactionInset: NSEdgeInsets = NSEdgeInsets(top: -10, left: -12, bottom: -8, right: -12),
        pointerCaptureRect: CGRect? = CGRect(x: 0.52, y: 0.56, width: 0.28, height: 0.30),
        previewPadding: NSEdgeInsets = NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
    ) -> DesktopPetViewLayout {
        DesktopPetViewLayout(
            panelSize: panelSize,
            backdropSize: backdropSize,
            cornerRadius: cornerRadius,
            riveInset: riveInset,
            interactionInset: interactionInset,
            pointerCaptureRect: pointerCaptureRect,
            previewPadding: previewPadding,
            attachment: attachment
        )
    }

    static var sceneKitLayout: DesktopPetViewLayout {
        DesktopPetViewLayout(
            panelSize: NSSize(width: 208, height: 208),
            backdropSize: .zero,
            cornerRadius: 0,
            riveInset: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            interactionInset: NSEdgeInsets(top: -10, left: -10, bottom: -10, right: -10),
            pointerCaptureRect: nil,
            previewPadding: NSEdgeInsets(top: 36, left: 36, bottom: 36, right: 36),
            attachment: DesktopPetAttachmentLayout(
                preferredSide: .left,
                overlap: 36,
                horizontalOffset: 0,
                verticalOffset: 26,
                screenPadding: 12
            )
        )
    }
}
