//
//  SpeedTestResult.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct SpeedTestResult: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let serverName: String
    let latencyMilliseconds: Double?
    let downloadMbps: Double
    let uploadMbps: Double
    let startedAt: Date
    let finishedAt: Date

    init(
        id: UUID = UUID(),
        serverName: String,
        latencyMilliseconds: Double?,
        downloadMbps: Double,
        uploadMbps: Double,
        startedAt: Date,
        finishedAt: Date
    ) {
        self.id = id
        self.serverName = serverName
        self.latencyMilliseconds = latencyMilliseconds
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}
