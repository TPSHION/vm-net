//
//  ConfigurationView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

struct ConfigurationView: View {

    private enum Page {
        case settings
        case speedTest
        case diagnosis
        case desktopPet
    }

    @ObservedObject var preferences: AppPreferences
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @ObservedObject var speedTestStore: SpeedTestStore
    @ObservedObject var diagnosisStore: NetworkDiagnosisStore
    let onFloatingBallToggle: (Bool) -> Void
    let onDesktopPetToggle: (Bool) -> Void
    let onDesktopPetRoamingToggle: (Bool) -> Void
    let onDesktopPetAssetApply: (DesktopPetAssetID) -> Void
    @State private var page: Page = .settings

    var body: some View {
        Group {
            switch page {
            case .settings:
                settingsPage
            case .speedTest:
                speedTestPage
            case .diagnosis:
                diagnosisPage
            case .desktopPet:
                desktopPetPage
            }
        }
        .environment(\.locale, preferences.appLanguage.locale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    launchSection
                    presentationSection
                    speedTestEntrySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var speedTestPage: some View {
        SpeedTestPageView(store: speedTestStore) {
            page = .settings
        }
    }

    private var diagnosisPage: some View {
        NetworkDiagnosisPageView(store: diagnosisStore) {
            page = .settings
        }
    }

    private var desktopPetPage: some View {
        DesktopPetSettingsPageView(
            preferences: preferences,
            onBack: {
                page = .settings
            },
            onDesktopPetToggle: onDesktopPetToggle,
            onDesktopPetRoamingToggle: onDesktopPetRoamingToggle,
            onDesktopPetAssetApply: onDesktopPetAssetApply
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("settings.header.subtitle"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var launchSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: launchAtLoginBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.tr("settings.launch.autoStart.title"))
                            .font(.system(size: 13, weight: .medium))

                        Text(L10n.tr("settings.launch.autoStart.subtitle"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if launchAtLoginManager.requiresApproval {
                    ViewThatFits(in: .horizontal) {
                        launchApprovalRow
                        launchApprovalColumn
                    }
                } else if let lastErrorMessage = launchAtLoginManager.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L10n.tr("settings.language.title"))
                            .font(.system(size: 13, weight: .medium))

                        Spacer(minLength: 16)

                        Picker(
                            L10n.tr("settings.language.title"),
                            selection: $preferences.appLanguage
                        ) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Text(L10n.tr("settings.language.description"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text(L10n.tr("settings.launch.sectionTitle"))
        }
    }

    private var presentationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: floatingBallBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.tr("settings.presentation.floatingBall.title"))
                            .font(.system(size: 13, weight: .medium))

                        Text(L10n.tr("settings.presentation.floatingBall.subtitle"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: desktopPetBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.tr("settings.presentation.desktopPet.title"))
                            .font(.system(size: 13, weight: .medium))

                        Text(L10n.tr("settings.presentation.desktopPet.subtitle", preferences.desktopPetAsset.displayName))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                desktopPetEntryButton

                if preferences.showDesktopPet && !preferences.showInFloatingBall {
                    Text(L10n.tr("desktopPet.requiresFloatingBall"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.tr("settings.presentation.appearanceHint"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    colorPickerRow(
                        title: L10n.tr("settings.presentation.backgroundColor"),
                        selection: floatingBallBackgroundColorBinding
                    )

                    colorPickerRow(
                        title: L10n.tr("settings.presentation.textColor"),
                        selection: floatingBallTextColorBinding
                    )

                    colorPreviewCard

                    labeledSlider(
                        title: L10n.tr("settings.presentation.backgroundTransparency"),
                        value: $preferences.floatingBallBackgroundTransparency,
                        range: 0...0.6,
                        description: backgroundTransparencySummary
                    )

                    ViewThatFits(in: .horizontal) {
                        appearanceFooterRow
                        appearanceFooterColumn
                    }
                }

                Divider()

                ViewThatFits(in: .horizontal) {
                    displayModeHeaderRow
                    displayModeHeaderColumn
                }

                Picker(L10n.tr("settings.presentation.displayMode"), selection: $preferences.displayMode) {
                    ForEach(ThroughputDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(preferences.displayMode.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text(L10n.tr("settings.presentation.sectionTitle"))
        }
    }

    private var speedTestEntrySection: some View {
        GroupBox {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    speedTestEntryButton
                    diagnosisEntryButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    speedTestEntryButton
                    diagnosisEntryButton
                }
            }
            .padding(4)
        } label: {
            Text(L10n.tr("settings.features.sectionTitle"))
        }
    }

    private func labeledSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 16)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)
        }
    }

    private var backgroundTransparencySummary: String {
        "\(Int(round(preferences.floatingBallBackgroundTransparency * 100)))%"
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginManager.isEnabled },
            set: { launchAtLoginManager.setEnabled($0) }
        )
    }

    private var floatingBallBinding: Binding<Bool> {
        Binding(
            get: { preferences.showInFloatingBall },
            set: { newValue in
                preferences.showInFloatingBall = newValue
                onFloatingBallToggle(newValue)
            }
        )
    }

    private var floatingBallBackgroundColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: preferences.floatingBallBackgroundColor) },
            set: { preferences.floatingBallBackgroundColor = NSColor($0) }
        )
    }

    private var desktopPetBinding: Binding<Bool> {
        Binding(
            get: { preferences.showDesktopPet },
            set: { newValue in
                preferences.showDesktopPet = newValue
                onDesktopPetToggle(newValue)
            }
        )
    }

    private var floatingBallTextColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: preferences.floatingBallTextColor) },
            set: { preferences.floatingBallTextColor = NSColor($0) }
        )
    }

    private var colorPreviewCard: some View {
        let fillOpacity = max(0.4, 1 - preferences.floatingBallBackgroundTransparency)

        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("settings.presentation.currentEffect"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                Spacer(minLength: 0)

                VStack(
                    alignment: .leading,
                    spacing: FloatingBallContentView.contentRowSpacing
                ) {
                    previewRow(symbol: "↑", value: "49K/s")
                    previewRow(symbol: "↓", value: "1.9K/s")
                }
                .padding(.horizontal, FloatingBallContentView.contentHorizontalPadding)
                .padding(.vertical, FloatingBallContentView.contentVerticalPadding)
                .frame(
                    width: FloatingBallContentView.capsuleSize.width,
                    height: FloatingBallContentView.capsuleSize.height,
                    alignment: .leading
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: FloatingBallContentView.capsuleCornerRadius,
                        style: .continuous
                    )
                        .fill(
                            Color(nsColor: preferences.floatingBallBackgroundColor)
                                .opacity(fillOpacity)
                        )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: FloatingBallContentView.capsuleCornerRadius,
                        style: .continuous
                    )
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func previewRow(symbol: String, value: String) -> some View {
        HStack(spacing: FloatingBallContentView.contentItemSpacing) {
            Text(symbol)
                .font(.system(size: FloatingBallContentView.symbolFontSize, weight: .bold))

            Text(value)
                .font(
                    .system(
                        size: FloatingBallContentView.valueFontSize,
                        weight: .semibold,
                        design: .monospaced
                    )
                )
        }
        .foregroundStyle(Color(nsColor: preferences.floatingBallTextColor))
    }

    private func colorPickerRow(
        title: String,
        selection: Binding<Color>
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 12)

            ColorPicker("", selection: selection, supportsOpacity: false)
                .labelsHidden()
        }
    }

    private var launchApprovalRow: some View {
        HStack(spacing: 10) {
            Text(L10n.tr("settings.launch.approvalHint"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button(L10n.tr("settings.launch.openSystemSettings")) {
                launchAtLoginManager.openSystemSettings()
            }
            .controlSize(.small)
        }
    }

    private var launchApprovalColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("settings.launch.approvalHint"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button(L10n.tr("settings.launch.openSystemSettings")) {
                launchAtLoginManager.openSystemSettings()
            }
            .controlSize(.small)
        }
    }

    private var appearanceFooterRow: some View {
        HStack(spacing: 12) {
            Text(L10n.tr("settings.presentation.appearanceApplyHint"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Button(L10n.tr("settings.presentation.resetAppearance")) {
                preferences.resetFloatingBallAppearance()
            }
            .controlSize(.small)
        }
    }

    private var appearanceFooterColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("settings.presentation.appearanceApplyHint"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button(L10n.tr("settings.presentation.resetAppearance")) {
                preferences.resetFloatingBallAppearance()
            }
            .controlSize(.small)
        }
    }

    private var displayModeHeaderRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.tr("settings.presentation.displayMode"))
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 16)

            Text(preferences.displayMode.title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var displayModeHeaderColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("settings.presentation.displayMode"))
                .font(.system(size: 13, weight: .medium))

            Text(preferences.displayMode.title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var speedTestEntryButton: some View {
        featureEntryButton(
            title: L10n.tr("settings.feature.speedTest.title"),
            subtitle: L10n.tr("settings.feature.speedTest.subtitle")
        ) {
            page = .speedTest
        }
    }

    private var desktopPetEntryButton: some View {
        featureEntryButton(
            title: L10n.tr("settings.feature.desktopPet.title"),
            subtitle: L10n.tr("settings.feature.desktopPet.subtitle", preferences.desktopPetAsset.displayName)
        ) {
            page = .desktopPet
        }
    }

    private var diagnosisEntryButton: some View {
        featureEntryButton(
            title: L10n.tr("settings.feature.diagnosis.title"),
            subtitle: L10n.tr("settings.feature.diagnosis.subtitle")
        ) {
            page = .diagnosis
        }
    }

    private func featureEntryButton(
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
        }
        .buttonStyle(.plain)
    }
}
