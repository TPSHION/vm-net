//
//  NetworkDiagnosisResult.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct NetworkDiagnosisResult: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let targetHost: String
    let overallStatus: NetworkDiagnosisCheckStatus
    let headline: String
    let summary: String
    let checks: [NetworkDiagnosisCheck]
    let dnsLatencyMilliseconds: Double?
    let httpsLatencyMilliseconds: Double?
    let httpStatusCode: Int?
    let startedAt: Date
    let finishedAt: Date

    init(
        id: UUID = UUID(),
        targetHost: String,
        overallStatus: NetworkDiagnosisCheckStatus,
        headline: String,
        summary: String,
        checks: [NetworkDiagnosisCheck],
        dnsLatencyMilliseconds: Double?,
        httpsLatencyMilliseconds: Double?,
        httpStatusCode: Int?,
        startedAt: Date,
        finishedAt: Date
    ) {
        self.id = id
        self.targetHost = targetHost
        self.overallStatus = overallStatus
        self.headline = headline
        self.summary = summary
        self.checks = checks
        self.dnsLatencyMilliseconds = dnsLatencyMilliseconds
        self.httpsLatencyMilliseconds = httpsLatencyMilliseconds
        self.httpStatusCode = httpStatusCode
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}
