//
//  SpeedTestSnapshot.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct SpeedTestSnapshot: Equatable {
    let phase: SpeedTestPhase
    let statusMessage: String
    let serverName: String?
    let latencyMilliseconds: Double?
    let downloadMbps: Double?
    let uploadMbps: Double?
    let lastResult: SpeedTestResult?
    let lastUpdatedAt: Date?
    let errorMessage: String?

    static let idle = SpeedTestSnapshot(
        phase: .idle,
        statusMessage: L10n.tr("speedTest.snapshot.idleStatus"),
        serverName: nil,
        latencyMilliseconds: nil,
        downloadMbps: nil,
        uploadMbps: nil,
        lastResult: nil,
        lastUpdatedAt: nil,
        errorMessage: nil
    )

    var isRunning: Bool {
        phase.isRunning
    }
}
