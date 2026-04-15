//
//  NetworkDiagnosisSnapshot.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct NetworkDiagnosisSnapshot: Equatable {
    let phase: NetworkDiagnosisPhase
    let statusMessage: String
    let targetHost: String
    let checks: [NetworkDiagnosisCheck]
    let lastResult: NetworkDiagnosisResult?
    let lastUpdatedAt: Date?
    let errorMessage: String?

    static let idle = NetworkDiagnosisSnapshot(
        phase: .idle,
        statusMessage: "手动发起一次网络诊断。",
        targetHost: NetworkDiagnosisTarget.cloudflare.host,
        checks: [],
        lastResult: nil,
        lastUpdatedAt: nil,
        errorMessage: nil
    )

    var isRunning: Bool {
        phase.isRunning
    }
}
