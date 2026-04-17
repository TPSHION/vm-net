//
//  NetworkDiagnosisCheck.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum NetworkDiagnosisCheckKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case path
    case dns
    case https

    var id: String { rawValue }

    var title: String {
        switch self {
        case .path:
            return L10n.tr("diagnosis.check.kind.path")
        case .dns:
            return L10n.tr("diagnosis.check.kind.dns")
        case .https:
            return L10n.tr("diagnosis.check.kind.https")
        }
    }
}

enum NetworkDiagnosisCheckStatus: String, Codable, Equatable, Sendable {
    case success
    case warning
    case failure
    case skipped

    var title: String {
        switch self {
        case .success:
            return L10n.tr("diagnosis.check.status.success")
        case .warning:
            return L10n.tr("diagnosis.check.status.warning")
        case .failure:
            return L10n.tr("diagnosis.check.status.failure")
        case .skipped:
            return L10n.tr("diagnosis.check.status.skipped")
        }
    }
}

struct NetworkDiagnosisCheck: Codable, Equatable, Identifiable, Sendable {
    var id: NetworkDiagnosisCheckKind { kind }

    let kind: NetworkDiagnosisCheckKind
    let status: NetworkDiagnosisCheckStatus
    let summary: String
    let detail: String?
}
