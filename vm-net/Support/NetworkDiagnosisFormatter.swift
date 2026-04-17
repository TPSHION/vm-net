//
//  NetworkDiagnosisFormatter.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

enum NetworkDiagnosisFormatter {

    static func latencyString(_ milliseconds: Double?) -> String {
        guard let milliseconds else { return L10n.tr("common.placeholder") }
        return String(format: "%.0f ms", milliseconds.rounded())
    }

    static func statusCodeString(_ statusCode: Int?) -> String {
        guard let statusCode else { return L10n.tr("common.placeholder") }
        return L10n.tr("common.httpStatusCode", statusCode)
    }

    static func timestampString(_ date: Date?) -> String {
        SpeedTestFormatter.historyTimestampString(date: date)
    }
}
