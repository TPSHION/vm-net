//
//  NetworkMonitor.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//

import Foundation

final class NetworkMonitor {

    private struct CounterSample {
        let sentBytes: UInt64
        let receivedBytes: UInt64
        let timestamp: Date
    }

    private let samplingInterval: TimeInterval
    private let queue: DispatchQueue

    private var lastSample: CounterSample?
    private var timer: DispatchSourceTimer?

    var updateHandler: ((NetworkThroughput) -> Void)?

    init(
        samplingInterval: TimeInterval = 2.0,
        queue: DispatchQueue = DispatchQueue(
            label: "cn.tpshion.vm-net.network-monitor"
        )
    ) {
        self.samplingInterval = samplingInterval
        self.queue = queue
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard timer == nil else { return }

        lastSample = snapshotCounters()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + samplingInterval,
            repeating: samplingInterval,
            leeway: .milliseconds(200)
        )
        timer.setEventHandler { [weak self] in
            self?.publishCurrentThroughput()
        }
        self.timer = timer
        timer.resume()
    }

    func stopMonitoring() {
        guard let timer else { return }

        timer.setEventHandler(handler: {})
        timer.cancel()

        self.timer = nil
        lastSample = nil
    }

    private func publishCurrentThroughput() {
        let currentSample = snapshotCounters()

        guard let previousSample = lastSample else {
            lastSample = currentSample
            return
        }

        lastSample = currentSample

        let elapsed = max(
            currentSample.timestamp.timeIntervalSince(previousSample.timestamp),
            0.001
        )
        let sentDelta = currentSample.sentBytes >= previousSample.sentBytes
            ? currentSample.sentBytes - previousSample.sentBytes
            : 0
        let receivedDelta = currentSample.receivedBytes
            >= previousSample.receivedBytes
            ? currentSample.receivedBytes - previousSample.receivedBytes
            : 0
        let throughput = NetworkThroughput(
            uploadBytesPerSecond: Double(sentDelta) / elapsed,
            downloadBytesPerSecond: Double(receivedDelta) / elapsed
        )
        let handler = updateHandler

        DispatchQueue.main.async {
            handler?(throughput)
        }
    }

    private func snapshotCounters() -> CounterSample {
        let totals = readNetworkTotals()

        return CounterSample(
            sentBytes: totals.sentBytes,
            receivedBytes: totals.receivedBytes,
            timestamp: Date()
        )
    }

    private func readNetworkTotals() -> (sentBytes: UInt64, receivedBytes: UInt64) {
        var mib = [CTL_NET, AF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0 else {
            return (0, 0)
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer { buffer.deallocate() }

        guard sysctl(&mib, UInt32(mib.count), buffer, &length, nil, 0) == 0 else {
            return (0, 0)
        }

        var cursor = buffer
        let end = buffer + length
        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        while cursor < end {
            let header = cursor.withMemoryRebound(
                to: if_msghdr.self,
                capacity: 1
            ) { $0.pointee }

            guard header.ifm_msglen > 0 else { break }

            if header.ifm_type == RTM_IFINFO2 {
                let info = cursor.withMemoryRebound(
                    to: if_msghdr2.self,
                    capacity: 1
                ) { $0.pointee }

                if shouldIncludeInterface(info) {
                    totalReceived += info.ifm_data.ifi_ibytes
                    totalSent += info.ifm_data.ifi_obytes
                }
            }

            cursor += Int(header.ifm_msglen)
        }

        return (totalSent, totalReceived)
    }

    private func shouldIncludeInterface(_ info: if_msghdr2) -> Bool {
        let flags = Int32(info.ifm_flags)

        return (flags & IFF_UP) != 0 && (flags & IFF_LOOPBACK) == 0
    }
}
