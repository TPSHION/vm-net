//
//  SpeedTestFormatter.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum SpeedTestFormatter {

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let historyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    static func throughputString(mbps: Double?) -> String {
        guard let mbps else { return "—" }

        if mbps < 10 {
            return String(format: "%.1f Mbps", mbps)
        }

        if mbps < 100 {
            return String(format: "%.0f Mbps", mbps)
        }

        return String(format: "%.0f Mbps", mbps.rounded())
    }

    static func latencyString(milliseconds: Double?) -> String {
        guard let milliseconds else { return "—" }
        return String(format: "%.0f ms", milliseconds.rounded())
    }

    static func timestampString(date: Date?) -> String? {
        guard let date else { return nil }
        return timeFormatter.string(from: date)
    }

    static func historyTimestampString(date: Date?) -> String {
        guard let date else { return "—" }

        if Calendar.current.isDateInToday(date) {
            return "今天 \(timeFormatter.string(from: date))"
        }

        return historyFormatter.string(from: date)
    }
}
