//
//  ActivityTimelineStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Combine
import Foundation

@MainActor
final class ActivityTimelineStore: ObservableObject {

    private enum Constants {
        static let recentLimit = 24
        static let dominantProcessThreshold = 512 * 1024.0
        static let dominantEventCooldown: TimeInterval = 20
        static let quietThreshold = 128 * 1024.0
        static let quietSampleRequirement = 5
    }

    @Published private(set) var recentEvents: [NetworkActivityTimelineEvent] = []

    private let processTrafficStore: ProcessTrafficStore
    private let alertStore: AlertStore
    private var cancellables = Set<AnyCancellable>()
    private var seenAnomalyIDs = Set<UUID>()
    private var lastObservedPhase: ProcessTrafficPhase?
    private var dominantProcessIdentity: String?
    private var lastDominantEventAt: Date?
    private var quietSamples = 0

    init(
        processTrafficStore: ProcessTrafficStore,
        alertStore: AlertStore
    ) {
        self.processTrafficStore = processTrafficStore
        self.alertStore = alertStore
        bind()
    }

    func reloadLocalization() {
        recentEvents = recentEvents.map { event in
            NetworkActivityTimelineEvent(
                id: event.id,
                occurredAt: event.occurredAt,
                kind: event.kind,
                severity: event.severity,
                processName: event.processName,
                bundleIdentifier: event.bundleIdentifier,
                metricValue: event.metricValue,
                detail: event.detail,
                headline: localizedHeadline(for: event),
                summary: localizedSummary(for: event)
            )
        }
    }

    private func bind() {
        alertStore.$recentAnomalies
            .sink { [weak self] anomalies in
                self?.consume(anomalies: anomalies)
            }
            .store(in: &cancellables)

        processTrafficStore.$snapshot
            .sink { [weak self] snapshot in
                self?.consume(snapshot: snapshot)
            }
            .store(in: &cancellables)
    }

    private func consume(anomalies: [NetworkAnomaly]) {
        let newAnomalies = anomalies
            .filter { !seenAnomalyIDs.contains($0.id) }
            .sorted { $0.occurredAt < $1.occurredAt }

        guard !newAnomalies.isEmpty else { return }

        for anomaly in newAnomalies {
            seenAnomalyIDs.insert(anomaly.id)
            let event = timelineEvent(from: anomaly)
            append(event)
        }
    }

    private func consume(snapshot: ProcessTrafficSnapshot) {
        if lastObservedPhase != snapshot.phase {
            handlePhaseChange(snapshot)
            lastObservedPhase = snapshot.phase
        }

        guard snapshot.phase == .streaming else { return }
        handleDominantProcess(snapshot)
    }

    private func handlePhaseChange(_ snapshot: ProcessTrafficSnapshot) {
        switch snapshot.phase {
        case .idle:
            break
        case .streaming:
            append(
                makeEvent(
                    occurredAt: snapshot.lastUpdatedAt ?? Date(),
                    kind: .collectorStreaming,
                    severity: .info,
                    processName: nil,
                    bundleIdentifier: nil,
                    metricValue: nil,
                    detail: nil
                )
            )
        case .unavailable:
            append(
                makeEvent(
                    occurredAt: Date(),
                    kind: .collectorUnavailable,
                    severity: .warning,
                    processName: nil,
                    bundleIdentifier: nil,
                    metricValue: nil,
                    detail: nil
                )
            )
        case .failed:
            append(
                makeEvent(
                    occurredAt: Date(),
                    kind: .collectorFailed,
                    severity: .critical,
                    processName: nil,
                    bundleIdentifier: nil,
                    metricValue: nil,
                    detail: snapshot.errorMessage ?? snapshot.statusMessage
                )
            )
        }
    }

    private func handleDominantProcess(_ snapshot: ProcessTrafficSnapshot) {
        let sortedProcesses = snapshot.processes.sorted {
            $0.totalBytesPerSecond > $1.totalBytesPerSecond
        }
        guard let topProcess = sortedProcesses.first else {
            registerQuietSampleIfNeeded(at: snapshot.lastUpdatedAt ?? Date())
            return
        }

        let throughput = topProcess.totalBytesPerSecond
        guard throughput >= Constants.dominantProcessThreshold else {
            registerQuietSampleIfNeeded(at: snapshot.lastUpdatedAt ?? Date())
            return
        }

        quietSamples = 0
        let identity = dominantIdentity(for: topProcess)

        if dominantProcessIdentity == identity {
            return
        }

        if let lastDominantEventAt,
           let updatedAt = snapshot.lastUpdatedAt,
           updatedAt.timeIntervalSince(lastDominantEventAt) < Constants.dominantEventCooldown {
            dominantProcessIdentity = identity
            return
        }

        dominantProcessIdentity = identity
        lastDominantEventAt = snapshot.lastUpdatedAt ?? Date()

        append(
            makeEvent(
                occurredAt: snapshot.lastUpdatedAt ?? Date(),
                kind: .dominantProcess,
                severity: .info,
                processName: topProcess.processName,
                bundleIdentifier: topProcess.bundleIdentifier,
                metricValue: ByteRateFormatter().string(for: throughput),
                detail: nil
            )
        )
    }

    private func registerQuietSampleIfNeeded(at date: Date) {
        quietSamples += 1

        guard dominantProcessIdentity != nil else { return }
        guard quietSamples >= Constants.quietSampleRequirement else { return }

        dominantProcessIdentity = nil
        quietSamples = 0

        append(
            makeEvent(
                occurredAt: date,
                kind: .activityRecovered,
                severity: .info,
                processName: nil,
                bundleIdentifier: nil,
                metricValue: nil,
                detail: nil
            )
        )
    }

    private func timelineEvent(from anomaly: NetworkAnomaly) -> NetworkActivityTimelineEvent {
        let kind: NetworkActivityTimelineEventKind

        switch anomaly.kind {
        case .highDownload:
            kind = .anomalyHighDownload
        case .highUpload:
            kind = .anomalyHighUpload
        case .backgroundActivity:
            kind = .anomalyBackgroundActivity
        }

        return NetworkActivityTimelineEvent(
            id: UUID(),
            occurredAt: anomaly.occurredAt,
            kind: kind,
            severity: anomaly.severity == .critical ? .critical : .warning,
            processName: anomaly.processName,
            bundleIdentifier: anomaly.bundleIdentifier,
            metricValue: anomaly.metricValue,
            detail: nil,
            headline: anomaly.headline,
            summary: anomaly.summary
        )
    }

    private func append(_ event: NetworkActivityTimelineEvent) {
        recentEvents.insert(event, at: 0)
        if recentEvents.count > Constants.recentLimit {
            recentEvents = Array(recentEvents.prefix(Constants.recentLimit))
        }
    }

    private func makeEvent(
        occurredAt: Date,
        kind: NetworkActivityTimelineEventKind,
        severity: NetworkActivityTimelineEventSeverity,
        processName: String?,
        bundleIdentifier: String?,
        metricValue: String?,
        detail: String?
    ) -> NetworkActivityTimelineEvent {
        let baseEvent = NetworkActivityTimelineEvent(
            id: UUID(),
            occurredAt: occurredAt,
            kind: kind,
            severity: severity,
            processName: processName,
            bundleIdentifier: bundleIdentifier,
            metricValue: metricValue,
            detail: detail,
            headline: "",
            summary: ""
        )

        return NetworkActivityTimelineEvent(
            id: baseEvent.id,
            occurredAt: baseEvent.occurredAt,
            kind: baseEvent.kind,
            severity: baseEvent.severity,
            processName: baseEvent.processName,
            bundleIdentifier: baseEvent.bundleIdentifier,
            metricValue: baseEvent.metricValue,
            detail: baseEvent.detail,
            headline: localizedHeadline(for: baseEvent),
            summary: localizedSummary(for: baseEvent)
        )
    }

    private func localizedHeadline(for event: NetworkActivityTimelineEvent) -> String {
        switch event.kind {
        case .anomalyHighDownload:
            return L10n.tr(
                "activity.timeline.headline.anomalyHighDownload",
                event.processName ?? L10n.tr("common.placeholder")
            )
        case .anomalyHighUpload:
            return L10n.tr(
                "activity.timeline.headline.anomalyHighUpload",
                event.processName ?? L10n.tr("common.placeholder")
            )
        case .anomalyBackgroundActivity:
            return L10n.tr(
                "activity.timeline.headline.anomalyBackgroundActivity",
                event.processName ?? L10n.tr("common.placeholder")
            )
        case .dominantProcess:
            return L10n.tr(
                "activity.timeline.headline.dominantProcess",
                event.processName ?? L10n.tr("common.placeholder")
            )
        case .activityRecovered:
            return L10n.tr("activity.timeline.headline.activityRecovered")
        case .collectorStreaming:
            return L10n.tr("activity.timeline.headline.collectorStreaming")
        case .collectorUnavailable:
            return L10n.tr("activity.timeline.headline.collectorUnavailable")
        case .collectorFailed:
            return L10n.tr("activity.timeline.headline.collectorFailed")
        }
    }

    private func localizedSummary(for event: NetworkActivityTimelineEvent) -> String {
        switch event.kind {
        case .anomalyHighDownload:
            return L10n.tr(
                "activity.timeline.summary.anomalyHighDownload",
                event.metricValue ?? L10n.tr("common.placeholder")
            )
        case .anomalyHighUpload:
            return L10n.tr(
                "activity.timeline.summary.anomalyHighUpload",
                event.metricValue ?? L10n.tr("common.placeholder")
            )
        case .anomalyBackgroundActivity:
            return L10n.tr(
                "activity.timeline.summary.anomalyBackgroundActivity",
                event.metricValue ?? L10n.tr("common.placeholder")
            )
        case .dominantProcess:
            return L10n.tr(
                "activity.timeline.summary.dominantProcess",
                event.metricValue ?? L10n.tr("common.placeholder")
            )
        case .activityRecovered:
            return L10n.tr("activity.timeline.summary.activityRecovered")
        case .collectorStreaming:
            return L10n.tr("activity.timeline.summary.collectorStreaming")
        case .collectorUnavailable:
            return L10n.tr("activity.timeline.summary.collectorUnavailable")
        case .collectorFailed:
            return event.detail?.isEmpty == false
                ? event.detail!
                : L10n.tr("activity.timeline.summary.collectorFailedFallback")
        }
    }

    private func dominantIdentity(for process: ProcessTrafficProcessRecord) -> String {
        let bundleIdentifier = process.bundleIdentifier ?? process.processName
        return "\(process.pid)-\(bundleIdentifier)"
    }
}
