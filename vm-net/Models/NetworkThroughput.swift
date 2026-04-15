//
//  NetworkThroughput.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct NetworkThroughput: Equatable {
    let uploadBytesPerSecond: Double
    let downloadBytesPerSecond: Double

    var peakBytesPerSecond: Double {
        max(uploadBytesPerSecond, downloadBytesPerSecond)
    }

    var totalBytesPerSecond: Double {
        uploadBytesPerSecond + downloadBytesPerSecond
    }

    var isActive: Bool {
        totalBytesPerSecond >= 256
    }

    static let zero = NetworkThroughput(
        uploadBytesPerSecond: 0,
        downloadBytesPerSecond: 0
    )

    func smoothed(
        against previous: NetworkThroughput,
        factor: Double
    ) -> NetworkThroughput {
        guard factor > 0 else { return previous }
        guard factor < 1 else { return self }

        return NetworkThroughput(
            uploadBytesPerSecond: previous.uploadBytesPerSecond
                + (uploadBytesPerSecond - previous.uploadBytesPerSecond) * factor,
            downloadBytesPerSecond: previous.downloadBytesPerSecond
                + (downloadBytesPerSecond - previous.downloadBytesPerSecond) * factor
        )
    }
}
