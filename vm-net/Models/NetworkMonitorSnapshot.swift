//
//  NetworkMonitorSnapshot.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct NetworkMonitorSnapshot: Equatable {
    let monitoredInterfaceName: String?
    let instantaneousThroughput: NetworkThroughput
    let displayedThroughput: NetworkThroughput
    let history: [NetworkThroughput]
    let lastUpdatedAt: Date?

    static let idle = NetworkMonitorSnapshot(
        monitoredInterfaceName: nil,
        instantaneousThroughput: .zero,
        displayedThroughput: .zero,
        history: [],
        lastUpdatedAt: nil
    )
}
