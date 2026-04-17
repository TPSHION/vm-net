//
//  PetRenderer.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit

@MainActor
protocol PetRenderer: AnyObject {
    var view: NSView { get }
    var hasActiveInteraction: Bool { get }
    var eventCaptureRectInSelf: CGRect { get }
    var movementGuideLeadDelay: TimeInterval { get }

    func applyAsset(_ asset: DesktopPetAsset)
    func applyBehaviorState(
        _ state: PetBehaviorState,
        movementVector: CGVector?
    )
    func setAmbientInteractionEnabled(_ isEnabled: Bool)
    func playMovementGuide(toward vector: CGVector)
}

enum PetRendererFactory {

    @MainActor
    static func makeRenderer(for asset: DesktopPetAsset) -> PetRenderer {
        makeRenderer(
            for: PetDefinitionCatalog.definition(for: asset),
            asset: asset
        )
    }

    @MainActor
    static func makeRenderer(
        for definition: PetDefinition,
        asset: DesktopPetAsset
    ) -> PetRenderer {
        switch definition.renderBackend {
        case .rive:
            return RivePetRenderer(asset: asset)
        case .sceneKit:
            return DisabledPetRenderer(
                asset: asset,
                message: L10n.tr("desktopPet.renderer.unavailable", definition.displayName)
            )
        }
    }
}

@MainActor
final class RivePetRenderer: PetRenderer {

    private let contentView: DesktopPetContentView

    init(asset: DesktopPetAsset) {
        self.contentView = DesktopPetContentView(
            frame: NSRect(origin: .zero, size: asset.layout.panelSize),
            asset: asset
        )
    }

    var view: NSView { contentView }

    var hasActiveInteraction: Bool {
        contentView.hasActiveInteraction
    }

    var eventCaptureRectInSelf: CGRect {
        contentView.eventCaptureRectInSelf
    }

    var movementGuideLeadDelay: TimeInterval {
        contentView.movementGuideLeadDelay
    }

    func applyAsset(_ asset: DesktopPetAsset) {
        contentView.applyAsset(asset)
    }

    func applyBehaviorState(
        _ state: PetBehaviorState,
        movementVector: CGVector?
    ) {
        contentView.applyBehaviorState(state, movementVector: movementVector)
    }

    func setAmbientInteractionEnabled(_ isEnabled: Bool) {
        contentView.setAmbientInteractionEnabled(isEnabled)
    }

    func playMovementGuide(toward vector: CGVector) {
        contentView.playMovementGuide(toward: vector)
    }
}

@MainActor
final class DisabledPetRenderer: PetRenderer {

    private let containerView: DisabledPetRendererView

    init(asset: DesktopPetAsset, message: String) {
        self.containerView = DisabledPetRendererView(
            frame: NSRect(origin: .zero, size: asset.layout.panelSize),
            message: message
        )
    }

    var view: NSView { containerView }

    var hasActiveInteraction: Bool { false }

    var eventCaptureRectInSelf: CGRect { .zero }

    var movementGuideLeadDelay: TimeInterval { 0 }

    func applyAsset(_ asset: DesktopPetAsset) {
        containerView.frame = NSRect(origin: .zero, size: asset.layout.panelSize)
    }

    func applyBehaviorState(
        _ state: PetBehaviorState,
        movementVector: CGVector?
    ) {}

    func setAmbientInteractionEnabled(_ isEnabled: Bool) {}

    func playMovementGuide(toward vector: CGVector) {}
}

private final class DisabledPetRendererView: NSView {

    private let label = NSTextField(labelWithString: "")

    init(frame frameRect: NSRect, message: String) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        label.stringValue = message
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
