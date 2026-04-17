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

    private let bridge: ProcessTrafficHelperBridge

    init(bridge: ProcessTrafficHelperBridge = ProcessTrafficHelperBridge()) {
        self.bridge = bridge

        bridge.start { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }

    deinit {
        bridge.stop()
    }

    func reloadLocalization() {
        let localizedMessage: String

        switch snapshot.phase {
        case .idle:
            localizedMessage = L10n.tr("activity.process.status.idle")
        case .streaming:
            localizedMessage = L10n.tr(
                "activity.process.status.streaming",
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
