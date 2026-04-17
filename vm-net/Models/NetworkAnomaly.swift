//
//  NetworkAnomaly.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import Foundation

enum NetworkAnomalyKind: String, Equatable {
    case highDownload
    case highUpload
    case backgroundActivity

    var title: String {
        switch self {
        case .highDownload:
            return L10n.tr("activity.alert.kind.highDownload")
        case .highUpload:
            return L10n.tr("activity.alert.kind.highUpload")
        case .backgroundActivity:
            return L10n.tr("activity.alert.kind.backgroundActivity")
        }
    }
}

enum NetworkAnomalySeverity: String, Equatable {
    case warning
    case critical

    var tintColor: NSColor {
        switch self {
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }
}

struct NetworkAnomaly: Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let kind: NetworkAnomalyKind
    let severity: NetworkAnomalySeverity
    let processName: String
    let bundleIdentifier: String?
    let headline: String
    let summary: String
    let metricValue: String
}
