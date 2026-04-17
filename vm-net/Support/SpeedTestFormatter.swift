//
//  SpeedTestFormatter.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum SpeedTestFormatter {

    static func throughputString(mbps: Double?) -> String {
        guard let mbps else { return L10n.tr("common.placeholder") }

        if mbps < 10 {
            return String(format: "%.1f Mbps", mbps)
        }

        if mbps < 100 {
            return String(format: "%.0f Mbps", mbps)
        }

        return String(format: "%.0f Mbps", mbps.rounded())
    }

    static func latencyString(milliseconds: Double?) -> String {
        guard let milliseconds else { return L10n.tr("common.placeholder") }
        return String(format: "%.0f ms", milliseconds.rounded())
    }

    static func timestampString(date: Date?) -> String? {
        guard let date else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func historyTimestampString(date: Date?) -> String {
        guard let date else { return L10n.tr("common.placeholder") }

        if Calendar.current.isDateInToday(date) {
            return L10n.tr(
                "common.date.todayTime",
                date.formatted(date: .omitted, time: .shortened)
            )
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
