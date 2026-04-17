//
//  DesktopPetSettingsPageView.swift
//  vm-net
//
//  Created by Codex on 2026/4/16.
//

import AppKit
import SwiftUI

struct DesktopPetSettingsPageView: View {

    @ObservedObject var preferences: AppPreferences
    let onBack: () -> Void
    let onDesktopPetToggle: (Bool) -> Void
    let onDesktopPetRoamingToggle: (Bool) -> Void
    let onDesktopPetAssetApply: (DesktopPetAssetID) -> Void
    @State private var previewAssetID: DesktopPetAssetID

    init(
        preferences: AppPreferences,
        onBack: @escaping () -> Void,
        onDesktopPetToggle: @escaping (Bool) -> Void,
        onDesktopPetRoamingToggle: @escaping (Bool) -> Void,
        onDesktopPetAssetApply: @escaping (DesktopPetAssetID) -> Void
    ) {
        self.preferences = preferences
        self.onBack = onBack
        self.onDesktopPetToggle = onDesktopPetToggle
        self.onDesktopPetRoamingToggle = onDesktopPetRoamingToggle
        self.onDesktopPetAssetApply = onDesktopPetAssetApply
        _previewAssetID = State(initialValue: preferences.desktopPetAssetID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    previewSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: preferences.desktopPetAssetID) { newValue in
            guard !hasPendingPetSelection else { return }
            previewAssetID = newValue
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label(L10n.tr("navigation.backToSettings"), systemImage: "chevron.left")
            }
            .buttonStyle(.link)

            Spacer(minLength: 0)

            Text(previewAsset.displayName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
    }

    private var previewSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("desktopPet.preview.currentTitle"))
                        .font(.system(size: 13, weight: .medium))

                    Text(L10n.tr("desktopPet.preview.description"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    HStack {
                        Spacer(minLength: 0)

                        DesktopPetPreviewView(
                            asset: previewAsset,
                            ambientInteractionEnabled: true
                        )
                        .frame(
                            width: previewAsset.previewCanvasSize.width,
                            height: previewAsset.previewCanvasSize.height
                        )

                        Spacer(minLength: 0)
                    }

                    if runtimeReadyAssets.count > 1 {
                        HStack {
                            previewNavigationButton(
                                symbol: "chevron.left",
                                action: showPreviousPreviewAsset
                            )

                            Spacer(minLength: 0)

                            previewNavigationButton(
                                symbol: "chevron.right",
                                action: showNextPreviewAsset
                            )
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )

                VStack(alignment: .leading, spacing: 4) {
                    if runtimeReadyAssets.count > 1 {
                        Text(L10n.tr("desktopPet.preview.switchHint", previewIndexLabel))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Text(L10n.tr("desktopPet.preview.appliedAsset", preferences.desktopPetAsset.displayName))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if hasPendingPetSelection {
                        Text(L10n.tr("desktopPet.preview.pendingAsset", previewAsset.displayName))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    } else {
                        Text(L10n.tr("desktopPet.preview.inSync"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                if runtimeReadyAssets.count > 1 {
                    HStack(spacing: 10) {
                        FirstMouseButton(L10n.tr("desktopPet.preview.restoreApplied")) {
                            previewAssetID = preferences.desktopPetAssetID
                        }
                        .disabled(!hasPendingPetSelection)

                        Spacer(minLength: 0)

                        FirstMouseButton(
                            L10n.tr("desktopPet.preview.apply"),
                            isProminent: true
                        ) {
                            onDesktopPetAssetApply(previewAssetID)
                        }
                        .disabled(!hasPendingPetSelection)
                    }
                }

                Divider()

                FirstMouseToggleRow(
                    title: L10n.tr("desktopPet.toggle.enable"),
                    isOn: desktopPetBinding
                )

                FirstMouseToggleRow(
                    title: L10n.tr("desktopPet.toggle.roaming"),
                    isOn: roamingBinding
                )

                if runtimeReadyAssets.count <= 1 {
                    Text(L10n.tr("desktopPet.singleAssetHint"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if preferences.showDesktopPet && !preferences.showInFloatingBall {
                    Text(L10n.tr("desktopPet.requiresFloatingBall"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(L10n.tr("desktopPet.preview.sectionTitle"))
        }
    }

    private var desktopPetBinding: Binding<Bool> {
        Binding(
            get: { preferences.showDesktopPet },
            set: {
                preferences.showDesktopPet = $0
                onDesktopPetToggle($0)
            }
        )
    }

    private var roamingBinding: Binding<Bool> {
        Binding(
            get: { preferences.desktopPetAllowsRoaming },
            set: {
                preferences.desktopPetAllowsRoaming = $0
                onDesktopPetRoamingToggle($0)
            }
        )
    }

    private var previewAsset: DesktopPetAsset {
        DesktopPetCatalog.asset(for: previewAssetID)
    }

    private var hasPendingPetSelection: Bool {
        previewAssetID != preferences.desktopPetAssetID
    }

    private var previewAssetIndex: Int {
        runtimeReadyAssets.firstIndex(where: { $0.id == previewAssetID }) ?? 0
    }

    private var previewIndexLabel: String {
        "\(previewAssetIndex + 1) / \(runtimeReadyAssets.count)"
    }

    private func showPreviousPreviewAsset() {
        guard !runtimeReadyAssets.isEmpty else { return }
        let nextIndex = (previewAssetIndex - 1 + runtimeReadyAssets.count) % runtimeReadyAssets.count
        previewAssetID = runtimeReadyAssets[nextIndex].id
    }

    private func showNextPreviewAsset() {
        guard !runtimeReadyAssets.isEmpty else { return }
        let nextIndex = (previewAssetIndex + 1) % runtimeReadyAssets.count
        previewAssetID = runtimeReadyAssets[nextIndex].id
    }

    @ViewBuilder
    private func previewNavigationButton(
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        FirstMouseButton(systemImage: symbol) {
            action()
        }
        .frame(width: 34, height: 34)
    }

    private var runtimeReadyAssets: [DesktopPetAsset] {
        PetDefinitionCatalog.allDefinitions
            .filter(\.isRuntimeReady)
            .compactMap { DesktopPetAssetID(rawValue: $0.id.rawValue) }
            .map(DesktopPetCatalog.asset(for:))
    }
}

private struct FirstMouseButton: NSViewRepresentable {

    let title: String
    let systemImage: String?
    var isProminent = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(
        _ title: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = nil
        self.isProminent = isProminent
        self.action = action
    }

    init(
        systemImage: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = ""
        self.systemImage = systemImage
        self.isProminent = isProminent
        self.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> FirstMouseNSButton {
        let button = FirstMouseNSButton(
            title: title,
            target: context.coordinator,
            action: #selector(Coordinator.performAction)
        )
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.focusRingType = .default
        update(button, coordinator: context.coordinator)
        return button
    }

    func updateNSView(_ nsView: FirstMouseNSButton, context: Context) {
        update(nsView, coordinator: context.coordinator)
    }

    private func update(
        _ button: FirstMouseNSButton,
        coordinator: Coordinator
    ) {
        coordinator.action = action
        button.title = title
        if let systemImage {
            button.image = NSImage(
                systemSymbolName: systemImage,
                accessibilityDescription: nil
            )
            button.imagePosition = .imageOnly
        } else {
            button.image = nil
            button.imagePosition = .noImage
        }
        button.isEnabled = isEnabled
        button.bezelColor = isProminent ? .controlAccentColor : nil
        button.contentTintColor = isProminent ? .white : nil
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc
        func performAction() {
            action()
        }
    }
}

private final class FirstMouseNSButton: NSButton {

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct FirstMouseToggleRow: View {

    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 0)

            FirstMouseToggleControl(isOn: $isOn)
                .frame(width: 38, height: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FirstMouseToggleControl: View {

    @Binding var isOn: Bool

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    isOn
                        ? Color.accentColor.opacity(0.95)
                        : Color(nsColor: .quaternaryLabelColor).opacity(0.32)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(isOn ? 0.18 : 0.3), lineWidth: 0.6)
                )

            Circle()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
                .padding(2)
                .offset(x: isOn ? 8 : -8)
        }
        .contentShape(Rectangle())
        .overlay {
            FirstMouseTapOverlay {
                isOn.toggle()
            }
        }
        .animation(.easeOut(duration: 0.16), value: isOn)
    }
}

private struct FirstMouseTapOverlay: NSViewRepresentable {

    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> FirstMouseTapNSView {
        let view = FirstMouseTapNSView()
        view.action = context.coordinator.performAction
        return view
    }

    func updateNSView(_ nsView: FirstMouseTapNSView, context: Context) {
        context.coordinator.action = action
        nsView.action = context.coordinator.performAction
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc
        func performAction() {
            action()
        }
    }
}

private final class FirstMouseTapNSView: NSView {

    var action: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseUp(with event: NSEvent) {
        action?()
    }
}

private struct DesktopPetPreviewView: NSViewRepresentable {

    let asset: DesktopPetAsset
    let ambientInteractionEnabled: Bool

    func makeNSView(context: Context) -> DesktopPetPreviewHostView {
        let view = DesktopPetPreviewHostView(asset: asset)
        view.setAmbientInteractionEnabled(ambientInteractionEnabled)
        return view
    }

    func updateNSView(_ nsView: DesktopPetPreviewHostView, context: Context) {
        nsView.apply(asset: asset)
        nsView.setAmbientInteractionEnabled(ambientInteractionEnabled)
    }

    static func dismantleNSView(
        _ nsView: DesktopPetPreviewHostView,
        coordinator: ()
    ) {
        nsView.setAmbientInteractionEnabled(false)
    }
}

private final class DesktopPetPreviewHostView: NSView {

    private var renderer: PetRenderer
    private var asset: DesktopPetAsset
    private var widthConstraint: NSLayoutConstraint
    private var heightConstraint: NSLayoutConstraint
    private var centerXConstraint: NSLayoutConstraint
    private var centerYConstraint: NSLayoutConstraint
    private var ambientInteractionEnabled = false

    init(asset: DesktopPetAsset) {
        self.asset = asset
        self.renderer = PetRendererFactory.makeRenderer(for: asset)
        self.widthConstraint = renderer.view.widthAnchor.constraint(
            equalToConstant: asset.layout.panelSize.width
        )
        self.heightConstraint = renderer.view.heightAnchor.constraint(
            equalToConstant: asset.layout.panelSize.height
        )
        self.centerXConstraint = renderer.view.centerXAnchor.constraint(
            equalTo: renderer.view.centerXAnchor
        )
        self.centerYConstraint = renderer.view.centerYAnchor.constraint(
            equalTo: renderer.view.centerYAnchor
        )

        super.init(frame: NSRect(origin: .zero, size: asset.previewCanvasSize))

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        renderer.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(renderer.view)

        centerXConstraint = renderer.view.centerXAnchor.constraint(
            equalTo: centerXAnchor,
            constant: asset.previewCenterOffset.x
        )
        centerYConstraint = renderer.view.centerYAnchor.constraint(
            equalTo: centerYAnchor,
            constant: asset.previewCenterOffset.y
        )

        NSLayoutConstraint.activate([
            centerXConstraint,
            centerYConstraint,
            widthConstraint,
            heightConstraint,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(asset: DesktopPetAsset) {
        let currentBackend = PetDefinitionCatalog.definition(for: self.asset).renderBackend
        let nextBackend = PetDefinitionCatalog.definition(for: asset).renderBackend
        let shouldRebuildRenderer = self.asset.id != asset.id || currentBackend != nextBackend

        self.asset = asset
        if shouldRebuildRenderer {
            rebuildRenderer(for: asset)
        } else {
            renderer.applyAsset(asset)
        }
        widthConstraint.constant = asset.layout.panelSize.width
        heightConstraint.constant = asset.layout.panelSize.height
        centerXConstraint.constant = asset.previewCenterOffset.x
        centerYConstraint.constant = asset.previewCenterOffset.y
        frame.size = asset.previewCanvasSize
        invalidateIntrinsicContentSize()
    }

    func setAmbientInteractionEnabled(_ isEnabled: Bool) {
        ambientInteractionEnabled = isEnabled
        renderer.setAmbientInteractionEnabled(isEnabled)
    }

    override var intrinsicContentSize: NSSize {
        asset.previewCanvasSize
    }

    private func rebuildRenderer(for asset: DesktopPetAsset) {
        let previousView = renderer.view
        previousView.removeFromSuperview()

        renderer = PetRendererFactory.makeRenderer(for: asset)
        renderer.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(renderer.view)

        NSLayoutConstraint.deactivate([
            widthConstraint,
            heightConstraint,
            centerXConstraint,
            centerYConstraint,
        ])

        widthConstraint = renderer.view.widthAnchor.constraint(
            equalToConstant: asset.layout.panelSize.width
        )
        heightConstraint = renderer.view.heightAnchor.constraint(
            equalToConstant: asset.layout.panelSize.height
        )
        centerXConstraint = renderer.view.centerXAnchor.constraint(
            equalTo: centerXAnchor,
            constant: asset.previewCenterOffset.x
        )
        centerYConstraint = renderer.view.centerYAnchor.constraint(
            equalTo: centerYAnchor,
            constant: asset.previewCenterOffset.y
        )

        NSLayoutConstraint.activate([
            centerXConstraint,
            centerYConstraint,
            widthConstraint,
            heightConstraint,
        ])

        renderer.applyAsset(asset)
        renderer.setAmbientInteractionEnabled(ambientInteractionEnabled)
    }
}
