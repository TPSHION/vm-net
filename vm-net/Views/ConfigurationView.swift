//
//  ConfigurationView.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit
import SwiftUI

struct ConfigurationView: View {

    private enum OverviewSeverity {
        case healthy
        case monitoring
        case warning
        case critical

        var tint: Color {
            switch self {
            case .healthy:
                return Color(nsColor: .systemGreen)
            case .monitoring:
                return Color(nsColor: .systemBlue)
            case .warning:
                return Color(nsColor: .systemOrange)
            case .critical:
                return Color(nsColor: .systemRed)
            }
        }

        var symbolName: String {
            switch self {
            case .healthy:
                return "checkmark.circle.fill"
            case .monitoring:
                return "waveform.path.ecg"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .critical:
                return "bolt.horizontal.circle.fill"
            }
        }

        var title: String {
            switch self {
            case .healthy:
                return L10n.tr("settings.dashboard.status.healthy")
            case .monitoring:
                return L10n.tr("settings.dashboard.status.monitoring")
            case .warning:
                return L10n.tr("settings.dashboard.status.warning")
            case .critical:
                return L10n.tr("settings.dashboard.status.critical")
            }
        }
    }

    @ObservedObject var preferences: AppPreferences
    @ObservedObject var navigationStore: ConfigurationNavigationStore
    @ObservedObject var desktopPetAccessStore: DesktopPetAccessStore
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @ObservedObject var throughputStore: ThroughputStore
    @ObservedObject var processTrafficStore: ProcessTrafficStore
    @ObservedObject var alertStore: AlertStore
    @ObservedObject var activityTimelineStore: ActivityTimelineStore
    @ObservedObject var speedTestStore: SpeedTestStore
    @ObservedObject var diagnosisStore: NetworkDiagnosisStore
    let onFloatingBallToggle: (Bool) -> Void
    let onDesktopPetToggle: (Bool) -> Void
    let onDesktopPetRoamingToggle: (Bool) -> Void
    let onDesktopPetAssetApply: (DesktopPetAssetID) -> Void
    @StateObject private var appStoreUpdateStore = AppStoreUpdateStore()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 244, max: 280)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.locale, preferences.appLanguage.locale)
    }

    private var sidebarSelection: Binding<ConfigurationPage?> {
        Binding(
            get: { navigationStore.page },
            set: { selection in
                guard let selection else { return }
                navigationStore.show(selection)
            }
        )
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            ForEach(ConfigurationPageGroup.allCases) { group in
                Section {
                    ForEach(group.pages) { page in
                        NavigationLink(value: page) {
                            ConfigurationSidebarRow(page: page)
                        }
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
        .listStyle(.sidebar)
        .id(preferences.appLanguage.rawValue)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch navigationStore.page {
        case .overview:
            overviewPage
        case .activity:
            activityPage
        case .diagnosis:
            diagnosisPage
        case .speedTest:
            speedTestPage
        case .desktopPet:
            desktopPetPage
        case .preferences:
            preferencesPage
        }
    }

    private var overviewPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            overviewHeaderSection

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    dashboardSection
                    quickActionsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            .vmNetScrollBarsHidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var preferencesPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeaderSection

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    launchSection
                    presentationSection
                    activitySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            .vmNetScrollBarsHidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var speedTestPage: some View {
        SpeedTestPageView(store: speedTestStore)
    }

    private var dashboardSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Label(overviewSeverity.title, systemImage: overviewSeverity.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(overviewSeverity.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(overviewSeverity.tint.opacity(0.12))
                        )

                    Spacer(minLength: 12)

                    if let timestamp = overviewTimestamp {
                        Text(timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(overviewHeadline)
                        .font(.system(size: 18, weight: .semibold))

                    Text(overviewSummary)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    overviewMetricCard(
                        title: L10n.tr("settings.dashboard.metric.download"),
                        value: currentDownloadRate
                    )
                    overviewMetricCard(
                        title: L10n.tr("settings.dashboard.metric.upload"),
                        value: currentUploadRate
                    )
                    overviewMetricCard(
                        title: L10n.tr("settings.dashboard.metric.interface"),
                        value: monitoredInterfaceName
                    )
                }

                if !preferences.activityAlertsEnabled {
                    Label(
                        L10n.tr("settings.dashboard.alertsDisabled"),
                        systemImage: "bell.slash"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    overviewSupplementTitle(L10n.tr("settings.dashboard.recentDiagnosis"))
                    diagnosisSummaryCard
                }

                VStack(alignment: .leading, spacing: 10) {
                    overviewSupplementTitle(L10n.tr("settings.dashboard.recentEvents"))

                    if recentTimelineEvents.isEmpty {
                        Text(L10n.tr("settings.events.empty"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentTimelineEvents) { event in
                            timelineSummaryRow(event)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Text(L10n.tr("settings.dashboard.sectionTitle"))
        }
    }

    private var quickActionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                quickActionButton(
                    title: diagnosisPrimaryActionTitle,
                    subtitle: diagnosisPrimaryActionSubtitle,
                    symbolName: diagnosisStore.snapshot.isRunning ? "stop.circle" : "stethoscope"
                ) {
                    if diagnosisStore.snapshot.isRunning {
                        diagnosisStore.cancelDiagnosis()
                    } else {
                        diagnosisStore.startDiagnosis()
                    }
                }

                quickActionButton(
                    title: L10n.tr("settings.actions.openDiagnosis.title"),
                    subtitle: L10n.tr("settings.actions.openDiagnosis.subtitle"),
                    symbolName: "list.clipboard"
                ) {
                    navigationStore.show(.diagnosis)
                }

                quickActionButton(
                    title: L10n.tr("settings.actions.openActivity.title"),
                    subtitle: L10n.tr("settings.actions.openActivity.subtitle"),
                    symbolName: "waveform.badge.magnifyingglass"
                ) {
                    navigationStore.show(.activity)
                }

                quickActionButton(
                    title: L10n.tr("settings.actions.speedTest.title"),
                    subtitle: L10n.tr("settings.actions.speedTest.subtitle"),
                    symbolName: "gauge.with.dots.needle.33percent"
                ) {
                    navigationStore.show(.speedTest)
                }
            }
            .padding(4)
        } label: {
            Text(L10n.tr("settings.actions.sectionTitle"))
        }
    }

    private var diagnosisPage: some View {
        NetworkDiagnosisPageView(store: diagnosisStore)
    }

    private var activityPage: some View {
        NetworkActivityPageView(
            processTrafficStore: processTrafficStore,
            alertStore: alertStore,
            activityTimelineStore: activityTimelineStore
        )
    }

    private var desktopPetPage: some View {
        DesktopPetSettingsPageView(
            preferences: preferences,
            desktopPetAccessStore: desktopPetAccessStore,
            onDesktopPetToggle: onDesktopPetToggle,
            onDesktopPetRoamingToggle: onDesktopPetRoamingToggle,
            onDesktopPetAssetApply: onDesktopPetAssetApply
        )
    }

    private var overviewHeaderSection: some View {
        pageTitleBlock(
            title: L10n.tr("navigation.overview.title"),
            subtitle: L10n.tr("navigation.overview.subtitle")
        )
    }

    private var preferencesHeaderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                pageTitleBlock(
                    title: L10n.tr("navigation.preferences.title"),
                    subtitle: L10n.tr("navigation.preferences.subtitle")
                )

                Spacer(minLength: 0)

                Button {
                    Task {
                        await appStoreUpdateStore.checkForUpdates()
                    }
                } label: {
                    if appStoreUpdateStore.isChecking {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.tr("settings.header.update.checking"))
                        }
                    } else {
                        Text(L10n.tr("settings.header.update.action"))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appStoreUpdateStore.isChecking)
            }

            if let updateMessage = appStoreUpdateStore.message {
                Text(updateMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(updateMessageColor)
            }
        }
    }

    private func pageTitleBlock(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func overviewSupplementTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var updateMessageColor: Color {
        switch appStoreUpdateStore.messageKind {
        case .neutral:
            return .secondary
        case .success:
            return Color(nsColor: .systemGreen)
        case .error:
            return Color(nsColor: .systemRed)
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

                desktopPetPremiumCard

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

    private var activitySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $preferences.activityAlertsEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.tr("settings.activity.alertsEnabled.title"))
                            .font(.system(size: 13, weight: .medium))

                        Text(L10n.tr("settings.activity.alertsEnabled.subtitle"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $preferences.activityAlertsEnableSystemNotifications) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.tr("settings.activity.systemNotifications.title"))
                            .font(.system(size: 13, weight: .medium))

                        Text(L10n.tr("settings.activity.systemNotifications.subtitle"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(!preferences.activityAlertsEnabled)

                if let latestAnomaly = alertStore.recentAnomalies.first {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("settings.activity.latestAlert"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(latestAnomaly.headline)
                            .font(.system(size: 13, weight: .medium))

                        Text(latestAnomaly.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text(L10n.tr("settings.activity.sectionTitle"))
        }
    }

    private var diagnosisSummaryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: diagnosisSummarySymbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(diagnosisSummaryTint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(diagnosisSummaryTitle)
                    .font(.system(size: 13, weight: .medium))

                Text(diagnosisSummarySubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let timestamp = diagnosisSummaryTimestamp {
                Text(timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func timelineSummaryRow(_ event: NetworkActivityTimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.severity.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(nsColor: event.severity.tintColor))
                .frame(width: 18, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.headline)
                    .font(.system(size: 13, weight: .medium))

                Text(event.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(event.occurredAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
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
                guard newValue else {
                    preferences.showDesktopPet = false
                    onDesktopPetToggle(false)
                    return
                }

                guard desktopPetAccessStore.prepareForUse() else {
                    preferences.showDesktopPet = false
                    navigationStore.show(.desktopPet)
                    return
                }

                preferences.showDesktopPet = newValue
                onDesktopPetToggle(newValue)
            }
        )
    }

    private var desktopPetAccessSummary: String {
        switch desktopPetAccessStore.status {
        case .loading:
            return L10n.tr("desktopPet.access.loading")
        case .eligibleForTrial:
            return L10n.tr("desktopPet.access.settings.eligible")
        case .inTrial(let daysRemaining, let expiresAt):
            return L10n.tr(
                "desktopPet.access.settings.trial",
                daysRemaining,
                DesktopPetAccessFormatter.expirationString(expiresAt)
            )
        case .unlocked:
            return L10n.tr("desktopPet.access.settings.unlocked")
        case .expired(let expiresAt):
            return L10n.tr(
                "desktopPet.access.settings.expired",
                DesktopPetAccessFormatter.expirationString(expiresAt)
            )
        }
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

    private var desktopPetPremiumCard: some View {
        Button {
            navigationStore.show(.desktopPet)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(L10n.tr("desktopPet.access.badge"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: desktopPetAccentColors,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )

                            Text(L10n.tr("desktopPet.access.marketingCaption"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(desktopPetAccessSummary)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        desktopPetHighlightChip(L10n.tr("desktopPet.access.highlight.trial"))
                        desktopPetHighlightChip(L10n.tr("desktopPet.access.highlight.unlock"))
                        desktopPetHighlightChip(L10n.tr("desktopPet.access.highlight.restore"))
                    }
                    .padding(.vertical, 1)
                }
                .vmNetScrollBarsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(desktopPetPremiumBackground)
        }
        .buttonStyle(.plain)
    }

    private func desktopPetHighlightChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.52))
            )
    }

    private var desktopPetAccentColors: [Color] {
        switch desktopPetAccessStore.status {
        case .unlocked:
            return [Color(red: 0.83, green: 0.64, blue: 0.23), Color(red: 0.58, green: 0.47, blue: 0.20)]
        case .expired:
            return [Color(red: 0.82, green: 0.47, blue: 0.23), Color(red: 0.60, green: 0.31, blue: 0.18)]
        case .loading, .eligibleForTrial, .inTrial:
            return [Color(red: 0.94, green: 0.72, blue: 0.26), Color(red: 0.82, green: 0.54, blue: 0.20)]
        }
    }

    private var desktopPetPremiumBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        desktopPetAccentColors[0].opacity(0.22),
                        Color(nsColor: .controlBackgroundColor).opacity(0.95),
                        desktopPetAccentColors[1].opacity(0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                desktopPetAccentColors[0].opacity(0.35),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        symbolName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)

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

    private func overviewMetricCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private var latestAlert: NetworkAnomaly? {
        alertStore.recentAnomalies.first
    }

    private var latestDiagnosisResult: NetworkDiagnosisResult? {
        diagnosisStore.recentResults.first
    }

    private var recentTimelineEvents: [NetworkActivityTimelineEvent] {
        Array(activityTimelineStore.recentEvents.prefix(3))
    }

    private var overviewSeverity: OverviewSeverity {
        if diagnosisStore.snapshot.isRunning {
            return .monitoring
        }

        if latestAlert?.severity == .critical
            || latestDiagnosisResult?.overallStatus == .failure {
            return .critical
        }

        if latestAlert != nil
            || latestDiagnosisResult?.overallStatus == .warning
            || latestDiagnosisResult?.overallStatus == .skipped {
            return .warning
        }

        return .healthy
    }

    private var overviewHeadline: String {
        if diagnosisStore.snapshot.isRunning {
            return diagnosisStore.snapshot.phase.title
        }

        if let latestAlert {
            return latestAlert.headline
        }

        if let latestDiagnosisResult {
            return latestDiagnosisResult.headline
        }

        return L10n.tr("settings.dashboard.headline.healthy")
    }

    private var overviewSummary: String {
        if diagnosisStore.snapshot.isRunning {
            return diagnosisStore.snapshot.statusMessage
        }

        if let latestAlert {
            return latestAlert.summary
        }

        if let latestDiagnosisResult {
            return latestDiagnosisResult.summary
        }

        guard throughputStore.snapshot.monitoredInterfaceName != nil else {
            return L10n.tr("settings.dashboard.summary.waitingInterface")
        }

        return L10n.tr("settings.dashboard.summary.healthy")
    }

    private var overviewTimestamp: Date? {
        if diagnosisStore.snapshot.isRunning {
            return diagnosisStore.snapshot.lastUpdatedAt
        }

        if let latestAlert {
            return latestAlert.occurredAt
        }

        if let latestDiagnosisResult {
            return latestDiagnosisResult.finishedAt
        }

        return throughputStore.snapshot.lastUpdatedAt
    }

    private var monitoredInterfaceName: String {
        throughputStore.snapshot.monitoredInterfaceName
            ?? L10n.tr("settings.dashboard.metric.interfaceUnavailable")
    }

    private var currentDownloadRate: String {
        ByteRateFormatter().string(
            for: throughputStore.snapshot.displayedThroughput.downloadBytesPerSecond
        )
    }

    private var currentUploadRate: String {
        ByteRateFormatter().string(
            for: throughputStore.snapshot.displayedThroughput.uploadBytesPerSecond
        )
    }

    private var diagnosisPrimaryActionTitle: String {
        diagnosisStore.snapshot.isRunning
            ? L10n.tr("settings.actions.stopDiagnosis.title")
            : L10n.tr("settings.actions.startDiagnosis.title")
    }

    private var diagnosisPrimaryActionSubtitle: String {
        diagnosisStore.snapshot.isRunning
            ? L10n.tr("settings.actions.stopDiagnosis.subtitle")
            : L10n.tr("settings.actions.startDiagnosis.subtitle")
    }

    private var diagnosisSummaryTitle: String {
        if diagnosisStore.snapshot.isRunning {
            return diagnosisStore.snapshot.phase.title
        }

        if let latestDiagnosisResult {
            return latestDiagnosisResult.headline
        }

        return L10n.tr("settings.events.diagnosis.emptyTitle")
    }

    private var diagnosisSummarySubtitle: String {
        if diagnosisStore.snapshot.isRunning {
            return diagnosisStore.snapshot.statusMessage
        }

        if let latestDiagnosisResult {
            return latestDiagnosisResult.summary
        }

        return L10n.tr("settings.events.diagnosis.emptySubtitle")
    }

    private var diagnosisSummaryTimestamp: Date? {
        if diagnosisStore.snapshot.isRunning {
            return diagnosisStore.snapshot.lastUpdatedAt
        }

        return latestDiagnosisResult?.finishedAt
    }

    private var diagnosisSummaryTint: Color {
        if diagnosisStore.snapshot.isRunning {
            return Color(nsColor: .systemBlue)
        }

        guard let latestDiagnosisResult else {
            return .secondary
        }

        switch latestDiagnosisResult.overallStatus {
        case .success:
            return Color(nsColor: .systemGreen)
        case .warning, .skipped:
            return Color(nsColor: .systemOrange)
        case .failure:
            return Color(nsColor: .systemRed)
        }
    }

    private var diagnosisSummarySymbolName: String {
        if diagnosisStore.snapshot.isRunning {
            return diagnosisStore.snapshot.phase.symbolName
        }

        guard let latestDiagnosisResult else {
            return "stethoscope.circle"
        }

        switch latestDiagnosisResult.overallStatus {
        case .success:
            return "checkmark.shield.fill"
        case .warning, .skipped:
            return "exclamationmark.shield.fill"
        case .failure:
            return "xmark.shield.fill"
        }
    }
}

private struct ConfigurationSidebarRow: View {

    let page: ConfigurationPage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: page.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(page.title)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}
