//
//  ProcessTrafficProcessRecord.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation

struct ProcessTrafficProcessRecord: Identifiable, Equatable {
    let pid: Int32
    let processName: String
    let bundleIdentifier: String?
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let activeConnectionCount: Int
    let remoteHostsTop: [String]
    let failureCountDelta: Int

    var id: String {
        let bundlePart = bundleIdentifier ?? processName
        return "\(pid)-\(bundlePart)"
    }

    var totalBytesPerSecond: Double {
        downloadBytesPerSecond + uploadBytesPerSecond
    }
}
