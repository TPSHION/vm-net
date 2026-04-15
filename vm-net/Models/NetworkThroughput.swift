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

    func stabilized(
        against previous: NetworkThroughput,
        minimumDelta: Double,
        relativeDelta: Double
    ) -> NetworkThroughput {
        NetworkThroughput(
            uploadBytesPerSecond: stabilizedComponent(
                uploadBytesPerSecond,
                previous: previous.uploadBytesPerSecond,
                minimumDelta: minimumDelta,
                relativeDelta: relativeDelta
            ),
            downloadBytesPerSecond: stabilizedComponent(
                downloadBytesPerSecond,
                previous: previous.downloadBytesPerSecond,
                minimumDelta: minimumDelta,
                relativeDelta: relativeDelta
            )
        )
    }

    private func stabilizedComponent(
        _ current: Double,
        previous: Double,
        minimumDelta: Double,
        relativeDelta: Double
    ) -> Double {
        let threshold = max(minimumDelta, previous * relativeDelta)
        return abs(current - previous) >= threshold ? current : previous
    }
}
