//
//  NetworkCountersSnapshot.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

struct NetworkCountersSnapshot: Equatable {
    struct InterfaceCounters: Equatable {
        let sentBytes: UInt64
        let receivedBytes: UInt64
    }

    let interfaceNames: [String]
    let interfaceCounters: [String: InterfaceCounters]
    let timestamp: Date

    var interfaceDisplayName: String {
        interfaceNames.joined(separator: ", ")
    }

    func matchesInterface(with other: NetworkCountersSnapshot) -> Bool {
        interfaceNames == other.interfaceNames
    }

    func throughput(since previous: NetworkCountersSnapshot) -> NetworkThroughput {
        let elapsed = max(timestamp.timeIntervalSince(previous.timestamp), 0.001)
        let sentDelta = interfaceNames.reduce(into: UInt64(0)) { partial, name in
            guard
                let currentCounters = interfaceCounters[name],
                let previousCounters = previous.interfaceCounters[name]
            else {
                return
            }

            partial += Self.delta(
                current: currentCounters.sentBytes,
                previous: previousCounters.sentBytes
            )
        }
        let receivedDelta = interfaceNames.reduce(into: UInt64(0)) {
            partial,
            name in
            guard
                let currentCounters = interfaceCounters[name],
                let previousCounters = previous.interfaceCounters[name]
            else {
                return
            }

            partial += Self.delta(
                current: currentCounters.receivedBytes,
                previous: previousCounters.receivedBytes
            )
        }

        return NetworkThroughput(
            uploadBytesPerSecond: Double(sentDelta) / elapsed,
            downloadBytesPerSecond: Double(receivedDelta) / elapsed
        )
    }

    private static func delta(current: UInt64, previous: UInt64) -> UInt64 {
        if current >= previous {
            return current - previous
        }

        // getifaddrs exposes if_data's 32-bit counters here, so we handle wrap.
        let counterCapacity = UInt64(UInt32.max) + 1
        return counterCapacity - previous + current
    }
}
