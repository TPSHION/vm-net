//
//  ProcessTrafficHelperBridge.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import Foundation

final class ProcessTrafficHelperBridge {

    private struct MutableProcessRecord {
        let pid: Int32
        let processName: String
        var downloadBytesPerSecond: Double
        var uploadBytesPerSecond: Double
        var activeConnectionCount: Int
        var remoteHostCounts: [String: Int]
        var failureCountDelta: Int

        var finalized: ProcessTrafficProcessRecord {
            let topHosts = remoteHostCounts
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value {
                        return lhs.key < rhs.key
                    }

                    return lhs.value > rhs.value
                }
                .prefix(3)
                .map(\.key)

            return ProcessTrafficProcessRecord(
                pid: pid,
                processName: processName,
                bundleIdentifier: nil,
                downloadBytesPerSecond: downloadBytesPerSecond,
                uploadBytesPerSecond: uploadBytesPerSecond,
                activeConnectionCount: activeConnectionCount,
                remoteHostsTop: topHosts,
                failureCountDelta: failureCountDelta
            )
        }
    }

    private enum Constants {
        static let nettopPath = "/usr/bin/nettop"
        static let minimumVisibleBytesPerSecond = 1.0
        static let samplingIntervalSeconds = 3
    }

    private let queue = DispatchQueue(
        label: "cn.tpshion.vm-net.process-traffic-bridge"
    )

    private var updateHandler: ((ProcessTrafficSnapshot) -> Void)?
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var textBuffer = ""
    private var hasSeenBaselineSample = false
    private var currentSample: [Int32: MutableProcessRecord] = [:]

    func start(updateHandler: @escaping (ProcessTrafficSnapshot) -> Void) {
        guard process == nil else { return }

        self.updateHandler = updateHandler

        queue.async { [weak self] in
            self?.startLocked()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    private func startLocked() {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: Constants.nettopPath)
        process.arguments = [
            "-P",
            "-c",
            "-d",
            "-L",
            "0",
            "-s",
            "\(Constants.samplingIntervalSeconds)",
            "-n",
            "-x",
            "-J",
            "bytes_in,bytes_out",
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async {
                self?.consumeOutput(data)
            }
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            self?.queue.async {
                self?.handleTermination(terminatedProcess)
            }
        }

        do {
            try process.run()
            self.process = process
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
        } catch {
            publish(ProcessTrafficSnapshot.failed(error.localizedDescription))
        }
    }

    private func stopLocked() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil

        if let process, process.isRunning {
            process.terminate()
        }

        process = nil
        outputPipe = nil
        errorPipe = nil
        updateHandler = nil
        textBuffer = ""
        hasSeenBaselineSample = false
        currentSample.removeAll(keepingCapacity: false)
    }

    private func handleTermination(_ terminatedProcess: Process) {
        guard process === terminatedProcess else { return }

        let errorMessage: String
        if let data = errorPipe?.fileHandleForReading.readDataToEndOfFile(),
           let stderrOutput = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stderrOutput.isEmpty {
            errorMessage = stderrOutput
        } else if terminatedProcess.terminationStatus == 0 {
            errorMessage = L10n.tr("activity.process.error.terminated")
        } else {
            errorMessage = L10n.tr(
                "activity.process.error.status",
                terminatedProcess.terminationStatus
            )
        }

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        errorPipe = nil
        textBuffer = ""
        hasSeenBaselineSample = false
        currentSample.removeAll(keepingCapacity: false)

        publish(ProcessTrafficSnapshot.failed(errorMessage))
    }

    private func consumeOutput(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }

        textBuffer.append(chunk)

        while let newlineRange = textBuffer.range(of: "\n") {
            let line = String(textBuffer[..<newlineRange.lowerBound])
            textBuffer.removeSubrange(textBuffer.startIndex...newlineRange.lowerBound)
            consumeLine(line)
        }
    }

    private func consumeLine(_ rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }

        if line.hasPrefix(",bytes_in,bytes_out") {
            finishCurrentSampleIfNeeded()
            currentSample.removeAll(keepingCapacity: true)
            return
        }

        let fields = line
            .split(separator: ",", omittingEmptySubsequences: false)
            .map(String.init)

        guard let firstField = fields.first else { return }

        if let (processName, pid) = parseProcessIdentifier(firstField) {
            currentSample[pid] = MutableProcessRecord(
                pid: pid,
                processName: processName,
                downloadBytesPerSecond: positiveNumber(at: 1, in: fields),
                uploadBytesPerSecond: positiveNumber(at: 2, in: fields),
                activeConnectionCount: 0,
                remoteHostCounts: [:],
                failureCountDelta: 0
            )
        }
    }

    private func finishCurrentSampleIfNeeded() {
        guard !currentSample.isEmpty else { return }

        if !hasSeenBaselineSample {
            hasSeenBaselineSample = true
            return
        }

        let processes = currentSample.values
            .map(\.finalized)
            .filter { record in
                record.downloadBytesPerSecond >= Constants.minimumVisibleBytesPerSecond
                    || record.uploadBytesPerSecond >= Constants.minimumVisibleBytesPerSecond
                    || record.activeConnectionCount > 0
            }
            .sorted { lhs, rhs in
                if lhs.totalBytesPerSecond == rhs.totalBytesPerSecond {
                    return lhs.processName.localizedCompare(rhs.processName) == .orderedAscending
                }

                return lhs.totalBytesPerSecond > rhs.totalBytesPerSecond
            }

        publish(
            ProcessTrafficSnapshot.streaming(
                processes: processes,
                lastUpdatedAt: Date()
            )
        )
    }

    private func parseProcessIdentifier(_ value: String) -> (String, Int32)? {
        guard let dotIndex = value.lastIndex(of: ".") else { return nil }

        let processName = String(value[..<dotIndex])
        let pidString = String(value[value.index(after: dotIndex)...])

        guard
            !processName.isEmpty,
            let pid = Int32(pidString)
        else {
            return nil
        }

        return (processName, pid)
    }

    private func positiveNumber(at index: Int, in fields: [String]) -> Double {
        guard fields.indices.contains(index) else { return 0 }

        let field = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !field.isEmpty else { return 0 }
        return Double(field) ?? 0
    }

    private func publish(_ snapshot: ProcessTrafficSnapshot) {
        guard let updateHandler else { return }

        DispatchQueue.main.async {
            let enrichedSnapshot: ProcessTrafficSnapshot

            if snapshot.phase == .streaming {
                let processes = snapshot.processes.map { process in
                    let runningApplication = NSRunningApplication(
                        processIdentifier: process.pid
                    )

                    return ProcessTrafficProcessRecord(
                        pid: process.pid,
                        processName: runningApplication?.localizedName
                            ?? process.processName,
                        bundleIdentifier: runningApplication?.bundleIdentifier,
                        downloadBytesPerSecond: process.downloadBytesPerSecond,
                        uploadBytesPerSecond: process.uploadBytesPerSecond,
                        activeConnectionCount: process.activeConnectionCount,
                        remoteHostsTop: process.remoteHostsTop,
                        failureCountDelta: process.failureCountDelta
                    )
                }

                enrichedSnapshot = ProcessTrafficSnapshot(
                    phase: snapshot.phase,
                    statusMessage: snapshot.statusMessage,
                    processes: processes,
                    lastUpdatedAt: snapshot.lastUpdatedAt,
                    errorMessage: snapshot.errorMessage
                )
            } else {
                enrichedSnapshot = snapshot
            }

            updateHandler(enrichedSnapshot)
        }
    }
}
