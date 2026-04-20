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
    let activeProcessCount: Int
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

    static let idle = ProcessTrafficSnapshot(
        phase: .idle,
        statusMessage: L10n.tr("activity.process.status.idle"),
        processes: [],
        activeProcessCount: 0,
        lastUpdatedAt: nil,
        errorMessage: nil
    )

    static func unavailable() -> ProcessTrafficSnapshot {
        ProcessTrafficSnapshot(
            phase: .unavailable,
            statusMessage: L10n.tr("activity.process.status.unavailable"),
            processes: [],
            activeProcessCount: 0,
            lastUpdatedAt: nil,
            errorMessage: nil
        )
    }

    static func streaming(
        processes: [ProcessTrafficProcessRecord],
        activeProcessCount: Int,
        lastUpdatedAt: Date
    ) -> ProcessTrafficSnapshot {
        ProcessTrafficSnapshot(
            phase: .streaming,
            statusMessage: L10n.tr(
                "activity.process.status.streamingEnhanced",
                activeProcessCount
            ),
            processes: processes,
            activeProcessCount: activeProcessCount,
            lastUpdatedAt: lastUpdatedAt,
            errorMessage: nil
        )
    }

    static func failed(_ message: String) -> ProcessTrafficSnapshot {
        ProcessTrafficSnapshot(
            phase: .failed,
            statusMessage: L10n.tr("activity.process.status.failed"),
            processes: [],
            activeProcessCount: 0,
            lastUpdatedAt: nil,
            errorMessage: message
        )
    }
}
