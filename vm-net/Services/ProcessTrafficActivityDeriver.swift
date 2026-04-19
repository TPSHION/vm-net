//
//  ProcessTrafficActivityDeriver.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import Foundation

struct ProcessTrafficSampleInput: Equatable {
    let pid: Int32
    let processName: String
    let bundleIdentifier: String?
    let isForegroundApp: Bool
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let activeConnectionCount: Int
    let remoteHostsTop: [String]
    let failureCountDelta: Int
}

struct ProcessTrafficSample: Equatable {
    let sampleTime: Date
    let processes: [ProcessTrafficSampleInput]
}

final class ProcessTrafficActivityDeriver {

    private struct HistoryEntry {
        let occurredAt: Date
        let downloadBytesPerSecond: Double
        let uploadBytesPerSecond: Double
        let failureCountDelta: Int
    }

    private struct ProcessState {
        var processName: String
        var bundleIdentifier: String?
        var isForegroundApp: Bool
        var history: [HistoryEntry]
    }

    private enum Constants {
        static let tenSecondWindow: TimeInterval = 10
        static let oneMinuteWindow: TimeInterval = 60
        static let highDownloadThreshold = 5 * 1024 * 1024.0
        static let highUploadThreshold = 1 * 1024 * 1024.0
        static let backgroundThreshold = 512 * 1024.0
        static let backgroundSampleRequirement = 3
        static let retryLikeFailureThreshold = 1
        static let burstMinimumCurrent = 1 * 1024 * 1024.0
        static let burstRatioThreshold = 2.0
        static let burstDeltaThreshold = 512 * 1024.0
    }

    private var states: [Int32: ProcessState] = [:]

    func reset() {
        states.removeAll(keepingCapacity: false)
    }

    func derive(sample: ProcessTrafficSample) -> [ProcessTrafficProcessRecord] {
        pruneState(olderThan: sample.sampleTime.addingTimeInterval(-Constants.oneMinuteWindow))

        var currentInputs: [Int32: ProcessTrafficSampleInput] = [:]
        currentInputs.reserveCapacity(sample.processes.count)

        for process in sample.processes {
            currentInputs[process.pid] = process

            var state = states[process.pid] ?? ProcessState(
                processName: process.processName,
                bundleIdentifier: process.bundleIdentifier,
                isForegroundApp: process.isForegroundApp,
                history: []
            )
            state.processName = process.processName
            state.bundleIdentifier = process.bundleIdentifier
            state.isForegroundApp = process.isForegroundApp
            state.history.append(
                HistoryEntry(
                    occurredAt: sample.sampleTime,
                    downloadBytesPerSecond: process.downloadBytesPerSecond,
                    uploadBytesPerSecond: process.uploadBytesPerSecond,
                    failureCountDelta: process.failureCountDelta
                )
            )
            states[process.pid] = state
        }

        pruneState(olderThan: sample.sampleTime.addingTimeInterval(-Constants.oneMinuteWindow))

        let recentPIDs = states.keys.sorted()
        var records: [ProcessTrafficProcessRecord] = []
        records.reserveCapacity(recentPIDs.count)

        for pid in recentPIDs {
            guard let state = states[pid] else { continue }

            let tenSecondEntries = state.history.filter {
                sample.sampleTime.timeIntervalSince($0.occurredAt) < Constants.tenSecondWindow
            }
            let current = currentInputs[pid]

            guard current != nil || !state.history.isEmpty else { continue }

            let record = ProcessTrafficProcessRecord(
                pid: pid,
                processName: state.processName,
                bundleIdentifier: state.bundleIdentifier,
                isForegroundApp: state.isForegroundApp,
                isCurrentSample: current != nil,
                downloadBytesPerSecond: current?.downloadBytesPerSecond ?? 0,
                uploadBytesPerSecond: current?.uploadBytesPerSecond ?? 0,
                tenSecondDownloadBytes: tenSecondEntries.reduce(into: 0) { partial, entry in
                    partial += entry.downloadBytesPerSecond
                },
                tenSecondUploadBytes: tenSecondEntries.reduce(into: 0) { partial, entry in
                    partial += entry.uploadBytesPerSecond
                },
                oneMinuteDownloadBytes: state.history.reduce(into: 0) { partial, entry in
                    partial += entry.downloadBytesPerSecond
                },
                oneMinuteUploadBytes: state.history.reduce(into: 0) { partial, entry in
                    partial += entry.uploadBytesPerSecond
                },
                activeConnectionCount: current?.activeConnectionCount ?? 0,
                remoteHostsTop: current?.remoteHostsTop ?? [],
                failureCountDelta: current?.failureCountDelta ?? 0,
                tags: tags(
                    current: current,
                    isForegroundApp: state.isForegroundApp,
                    tenSecondEntries: tenSecondEntries
                )
            )
            records.append(record)
        }

        return records.sorted(by: sortRecords(_:_:))
    }

    private func pruneState(olderThan cutoff: Date) {
        for pid in states.keys {
            guard var state = states[pid] else { continue }
            state.history.removeAll { $0.occurredAt < cutoff }

            if state.history.isEmpty {
                states.removeValue(forKey: pid)
            } else {
                states[pid] = state
            }
        }
    }

    private func tags(
        current: ProcessTrafficSampleInput?,
        isForegroundApp: Bool,
        tenSecondEntries: [HistoryEntry]
    ) -> [ProcessTrafficTag] {
        var tags: [ProcessTrafficTag] = []

        let currentDownload = current?.downloadBytesPerSecond ?? 0
        let currentUpload = current?.uploadBytesPerSecond ?? 0
        let currentTotal = currentDownload + currentUpload
        let recentFailureCount = tenSecondEntries.reduce(into: 0) { partial, entry in
            partial += entry.failureCountDelta
        }
        let backgroundHotSamples = tenSecondEntries.filter {
            ($0.downloadBytesPerSecond + $0.uploadBytesPerSecond) >= Constants.backgroundThreshold
        }.count

        if currentDownload >= Constants.highDownloadThreshold {
            tags.append(.highDownload)
        }

        if currentUpload >= Constants.highUploadThreshold {
            tags.append(.highUpload)
        }

        if !isForegroundApp && backgroundHotSamples >= Constants.backgroundSampleRequirement {
            tags.append(.backgroundActive)
        }

        if recentFailureCount >= Constants.retryLikeFailureThreshold {
            tags.append(.retryLike)
        }

        if isBurst(currentTotal: currentTotal, tenSecondEntries: tenSecondEntries) {
            tags.append(.burst)
        }

        return tags
    }

    private func isBurst(
        currentTotal: Double,
        tenSecondEntries: [HistoryEntry]
    ) -> Bool {
        guard currentTotal >= Constants.burstMinimumCurrent else { return false }
        guard tenSecondEntries.count >= 2 else { return false }

        let previousEntries = tenSecondEntries.dropLast()
        guard !previousEntries.isEmpty else { return false }

        let averagePreviousTotal = previousEntries.reduce(into: 0.0) { partial, entry in
            partial += entry.downloadBytesPerSecond + entry.uploadBytesPerSecond
        } / Double(previousEntries.count)

        guard averagePreviousTotal > 0 else { return false }

        return currentTotal >= averagePreviousTotal * Constants.burstRatioThreshold
            && (currentTotal - averagePreviousTotal) >= Constants.burstDeltaThreshold
    }

    private func sortRecords(
        _ lhs: ProcessTrafficProcessRecord,
        _ rhs: ProcessTrafficProcessRecord
    ) -> Bool {
        if lhs.totalBytesPerSecond != rhs.totalBytesPerSecond {
            return lhs.totalBytesPerSecond > rhs.totalBytesPerSecond
        }

        if lhs.oneMinuteTotalBytes != rhs.oneMinuteTotalBytes {
            return lhs.oneMinuteTotalBytes > rhs.oneMinuteTotalBytes
        }

        if lhs.processName != rhs.processName {
            return lhs.processName.localizedStandardCompare(rhs.processName)
                == .orderedAscending
        }

        return lhs.pid < rhs.pid
    }
}
