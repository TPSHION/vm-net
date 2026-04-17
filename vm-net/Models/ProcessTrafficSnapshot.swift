//
//  ProcessTrafficSnapshot.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation

struct ProcessTrafficSnapshot: Equatable {
    let phase: ProcessTrafficPhase
    let statusMessage: String
    let processes: [ProcessTrafficProcessRecord]
    let lastUpdatedAt: Date?
    let errorMessage: String?

    var totalDownloadBytesPerSecond: Double {
        processes.reduce(into: 0) { partial, record in
            partial += record.downloadBytesPerSecond
        }
    }

    var totalUploadBytesPerSecond: Double {
        processes.reduce(into: 0) { partial, record in
            partial += record.uploadBytesPerSecond
        }
    }

    var activeProcessCount: Int {
        processes.count
    }

    static let idle = ProcessTrafficSnapshot(
        phase: .idle,
        statusMessage: L10n.tr("activity.process.status.idle"),
        processes: [],
        lastUpdatedAt: nil,
        errorMessage: nil
    )

    static func unavailable() -> ProcessTrafficSnapshot {
        ProcessTrafficSnapshot(
            phase: .unavailable,
            statusMessage: L10n.tr("activity.process.status.unavailable"),
            processes: [],
            lastUpdatedAt: nil,
            errorMessage: nil
        )
    }
}
