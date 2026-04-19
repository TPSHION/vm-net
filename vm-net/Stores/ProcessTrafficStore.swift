//
//  ProcessTrafficStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Combine
import Foundation

@MainActor
final class ProcessTrafficStore: ObservableObject {

    @Published private(set) var snapshot: ProcessTrafficSnapshot = .idle
    @Published private(set) var isMonitoring = false

    private let bridge: ProcessTrafficHelperBridge
    private let activityDeriver: ProcessTrafficActivityDeriver

    init(
        bridge: ProcessTrafficHelperBridge = ProcessTrafficHelperBridge(),
        activityDeriver: ProcessTrafficActivityDeriver = ProcessTrafficActivityDeriver()
    ) {
        self.bridge = bridge
        self.activityDeriver = activityDeriver
    }

    deinit {
        bridge.stop()
    }

    func activateMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        activityDeriver.reset()

        bridge.start(
            sampleHandler: { [weak self] sample in
                self?.consume(sample)
            },
            errorHandler: { [weak self] message in
                self?.snapshot = .failed(message)
            }
        )
    }

    func deactivateMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        bridge.stop()
        activityDeriver.reset()
        snapshot = .idle
    }

    func reloadLocalization() {
        let localizedMessage: String

        switch snapshot.phase {
        case .idle:
            localizedMessage = L10n.tr("activity.process.status.idle")
        case .streaming:
            localizedMessage = L10n.tr(
                "activity.process.status.streamingEnhanced",
                snapshot.activeProcessCount
            )
        case .unavailable:
            localizedMessage = L10n.tr("activity.process.status.unavailable")
        case .failed:
            localizedMessage = L10n.tr("activity.process.status.failed")
        }

        snapshot = ProcessTrafficSnapshot(
            phase: snapshot.phase,
            statusMessage: localizedMessage,
            processes: snapshot.processes,
            activeProcessCount: snapshot.activeProcessCount,
            lastUpdatedAt: snapshot.lastUpdatedAt,
            errorMessage: snapshot.errorMessage
        )
    }

    private func consume(_ sample: ProcessTrafficSample) {
        let processes = activityDeriver.derive(sample: sample)
        snapshot = .streaming(
            processes: processes,
            activeProcessCount: sample.processes.count,
            lastUpdatedAt: sample.sampleTime
        )
    }
}
