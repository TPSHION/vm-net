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

    init(bridge: ProcessTrafficHelperBridge = ProcessTrafficHelperBridge()) {
        self.bridge = bridge
    }

    deinit {
        bridge.stop()
    }

    func activateMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        bridge.start { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }

    func deactivateMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        bridge.stop()
        snapshot = .idle
    }

    func reloadLocalization() {
        let localizedMessage: String

        switch snapshot.phase {
        case .idle:
            localizedMessage = L10n.tr("activity.process.status.idle")
        case .streaming:
            localizedMessage = L10n.tr(
                "activity.process.status.streamingLowPower",
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
            lastUpdatedAt: snapshot.lastUpdatedAt,
            errorMessage: snapshot.errorMessage
        )
    }
}
