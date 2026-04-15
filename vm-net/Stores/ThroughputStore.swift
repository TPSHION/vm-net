//
//  ThroughputStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Combine
import Foundation

@MainActor
final class ThroughputStore: ObservableObject {

    @Published private(set) var snapshot: NetworkMonitorSnapshot = .idle

    private let networkMonitor: NetworkMonitor

    init(networkMonitor: NetworkMonitor = NetworkMonitor()) {
        self.networkMonitor = networkMonitor

        self.networkMonitor.updateHandler = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
        self.networkMonitor.startMonitoring()
    }

    deinit {
        networkMonitor.stopMonitoring()
    }
}
