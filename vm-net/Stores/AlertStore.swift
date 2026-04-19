//
//  AlertStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import Combine
import Foundation

@MainActor
final class AlertStore: ObservableObject {

    private struct RuleCounters {
        var highDownloadSamples = 0
        var highUploadSamples = 0
        var backgroundSamples = 0
    }

    private enum Constants {
        static let recentLimit = 6
        static let highDownloadThreshold = 5 * 1024 * 1024.0
        static let highUploadThreshold = 1 * 1024 * 1024.0
        static let backgroundThreshold = 512 * 1024.0
        static let highTrafficSampleRequirement = 3
        static let backgroundSampleRequirement = 6
        static let cooldown: TimeInterval = 10 * 60
    }

    @Published private(set) var recentAnomalies: [NetworkAnomaly] = []

    private let preferences: AppPreferences
    private let processTrafficStore: ProcessTrafficStore
    private let notificationCenterHelper: NotificationCenterHelper
    private var cancellables = Set<AnyCancellable>()
    private var countersByProcessID: [Int32: RuleCounters] = [:]
    private var cooldowns: [String: Date] = [:]

    init(
        preferences: AppPreferences,
        processTrafficStore: ProcessTrafficStore,
        notificationCenterHelper: NotificationCenterHelper = NotificationCenterHelper()
    ) {
        self.preferences = preferences
        self.processTrafficStore = processTrafficStore
        self.notificationCenterHelper = notificationCenterHelper

        bind()
    }

    func reloadLocalization() {
        recentAnomalies = recentAnomalies.map { anomaly in
            NetworkAnomaly(
                id: anomaly.id,
                occurredAt: anomaly.occurredAt,
                kind: anomaly.kind,
                severity: anomaly.severity,
                processName: anomaly.processName,
                bundleIdentifier: anomaly.bundleIdentifier,
                headline: localizedHeadline(for: anomaly.kind, processName: anomaly.processName),
                summary: localizedSummary(
                    for: anomaly.kind,
                    processName: anomaly.processName,
                    metricValue: anomaly.metricValue
                ),
                metricValue: anomaly.metricValue
            )
        }
    }

    private func bind() {
        processTrafficStore.$snapshot
            .sink { [weak self] snapshot in
                self?.consume(snapshot)
            }
            .store(in: &cancellables)

        preferences.$activityAlertsEnableSystemNotifications
            .dropFirst()
            .sink { [weak self] isEnabled in
                guard isEnabled else { return }
                self?.notificationCenterHelper.requestAuthorizationIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func consume(_ snapshot: ProcessTrafficSnapshot) {
        guard preferences.activityAlertsEnabled else { return }
        guard snapshot.phase == .streaming else { return }

        var activeProcessIDs = Set<Int32>()

        for process in snapshot.processes where process.isCurrentSample {
            activeProcessIDs.insert(process.pid)

            var counters = countersByProcessID[process.pid] ?? RuleCounters()

            if process.downloadBytesPerSecond >= Constants.highDownloadThreshold {
                counters.highDownloadSamples += 1
            } else {
                counters.highDownloadSamples = 0
            }

            if process.uploadBytesPerSecond >= Constants.highUploadThreshold {
                counters.highUploadSamples += 1
            } else {
                counters.highUploadSamples = 0
            }

            let isBackgroundProcess = process.bundleIdentifier != nil
                && !process.isForegroundApp
                && process.bundleIdentifier != Bundle.main.bundleIdentifier
            if isBackgroundProcess && process.totalBytesPerSecond >= Constants.backgroundThreshold {
                counters.backgroundSamples += 1
            } else {
                counters.backgroundSamples = 0
            }

            countersByProcessID[process.pid] = counters

            if counters.highDownloadSamples == Constants.highTrafficSampleRequirement {
                raiseAnomaly(
                    kind: .highDownload,
                    severity: .critical,
                    process: process,
                    metricValue: ByteRateFormatter().string(
                        for: process.downloadBytesPerSecond
                    )
                )
            }

            if counters.highUploadSamples == Constants.highTrafficSampleRequirement {
                raiseAnomaly(
                    kind: .highUpload,
                    severity: .critical,
                    process: process,
                    metricValue: ByteRateFormatter().string(
                        for: process.uploadBytesPerSecond
                    )
                )
            }

            if counters.backgroundSamples == Constants.backgroundSampleRequirement {
                raiseAnomaly(
                    kind: .backgroundActivity,
                    severity: .warning,
                    process: process,
                    metricValue: ByteRateFormatter().string(
                        for: process.totalBytesPerSecond
                    )
                )
            }
        }

        countersByProcessID = countersByProcessID.filter { activeProcessIDs.contains($0.key) }
    }

    private func raiseAnomaly(
        kind: NetworkAnomalyKind,
        severity: NetworkAnomalySeverity,
        process: ProcessTrafficProcessRecord,
        metricValue: String
    ) {
        let cooldownKey = "\(kind.rawValue)-\(process.bundleIdentifier ?? process.processName)"
        let now = Date()

        if let lastDate = cooldowns[cooldownKey],
           now.timeIntervalSince(lastDate) < Constants.cooldown {
            return
        }

        cooldowns[cooldownKey] = now

        let anomaly = NetworkAnomaly(
            id: UUID(),
            occurredAt: now,
            kind: kind,
            severity: severity,
            processName: process.processName,
            bundleIdentifier: process.bundleIdentifier,
            headline: localizedHeadline(for: kind, processName: process.processName),
            summary: localizedSummary(
                for: kind,
                processName: process.processName,
                metricValue: metricValue
            ),
            metricValue: metricValue
        )

        recentAnomalies.insert(anomaly, at: 0)
        if recentAnomalies.count > Constants.recentLimit {
            recentAnomalies = Array(recentAnomalies.prefix(Constants.recentLimit))
        }

        if preferences.activityAlertsEnableSystemNotifications {
            notificationCenterHelper.requestAuthorizationIfNeeded()
            notificationCenterHelper.postNetworkAnomaly(anomaly)
        }
    }

    private func localizedHeadline(
        for kind: NetworkAnomalyKind,
        processName: String
    ) -> String {
        switch kind {
        case .highDownload:
            return L10n.tr("activity.alert.headline.highDownload", processName)
        case .highUpload:
            return L10n.tr("activity.alert.headline.highUpload", processName)
        case .backgroundActivity:
            return L10n.tr("activity.alert.headline.backgroundActivity", processName)
        }
    }

    private func localizedSummary(
        for kind: NetworkAnomalyKind,
        processName: String,
        metricValue: String
    ) -> String {
        switch kind {
        case .highDownload:
            return L10n.tr("activity.alert.summary.highDownload", processName, metricValue)
        case .highUpload:
            return L10n.tr("activity.alert.summary.highUpload", processName, metricValue)
        case .backgroundActivity:
            return L10n.tr("activity.alert.summary.backgroundActivity", processName, metricValue)
        }
    }
}
