//
//  NetworkActivityTimelineEvent.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import Foundation

enum NetworkActivityTimelineEventKind: String, Equatable {
    case anomalyHighDownload
    case anomalyHighUpload
    case anomalyBackgroundActivity
    case dominantProcess
    case activityRecovered
    case collectorStreaming
    case collectorUnavailable
    case collectorFailed
}

enum NetworkActivityTimelineEventSeverity: String, Equatable {
    case info
    case warning
    case critical

    var tintColor: NSColor {
        switch self {
        case .info:
            return .systemBlue
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }

    var symbolName: String {
        switch self {
        case .info:
            return "clock.arrow.circlepath"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "bolt.fill"
        }
    }
}

struct NetworkActivityTimelineEvent: Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let kind: NetworkActivityTimelineEventKind
    let severity: NetworkActivityTimelineEventSeverity
    let processName: String?
    let bundleIdentifier: String?
    let metricValue: String?
    let detail: String?
    let headline: String
    let summary: String
}
