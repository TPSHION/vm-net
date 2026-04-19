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
            ProcessTrafficProcessRecord(
                pid: pid,
                processName: processName,
                bundleIdentifier: nil,
                isForegroundApp: false,
                isCurrentSample: true,
                downloadBytesPerSecond: downloadBytesPerSecond,
                uploadBytesPerSecond: uploadBytesPerSecond,
                tenSecondDownloadBytes: 0,
                tenSecondUploadBytes: 0,
                oneMinuteDownloadBytes: 0,
                oneMinuteUploadBytes: 0,
                activeConnectionCount: activeConnectionCount,
                remoteHostsTop: remoteHostCounts
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            return lhs.key < rhs.key
                        }

                        return lhs.value > rhs.value
                    }
                    .prefix(3)
                    .map(\.key),
                failureCountDelta: failureCountDelta,
                tags: []
            )
        }

        var sampleInput: ProcessTrafficSampleInput {
            ProcessTrafficSampleInput(
                pid: pid,
                processName: processName,
                bundleIdentifier: nil,
                isForegroundApp: false,
                downloadBytesPerSecond: downloadBytesPerSecond,
                uploadBytesPerSecond: uploadBytesPerSecond,
                activeConnectionCount: activeConnectionCount,
                remoteHostsTop: remoteHostCounts
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value {
                        return lhs.key < rhs.key
                    }

                    return lhs.value > rhs.value
                }
                .prefix(3)
                .map(\.key),
                failureCountDelta: failureCountDelta
            )
        }
    }

    private enum Constants {
        static let nettopPath = "/usr/bin/nettop"
        static let minimumVisibleBytesPerSecond = 1.0
        static let samplingIntervalSeconds = 1
    }

    private let queue = DispatchQueue(
        label: "cn.tpshion.vm-net.process-traffic-bridge"
    )

    private var sampleHandler: ((ProcessTrafficSample) -> Void)?
    private var errorHandler: ((String) -> Void)?
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var textBuffer = ""
    private var hasSeenBaselineSample = false
    private var currentSample: [Int32: MutableProcessRecord] = [:]
    private var currentProcessID: Int32?

    func start(
        sampleHandler: @escaping (ProcessTrafficSample) -> Void,
        errorHandler: @escaping (String) -> Void
    ) {
        guard process == nil else { return }

        self.sampleHandler = sampleHandler
        self.errorHandler = errorHandler

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
            "-d",
            "-L",
            "0",
            "-s",
            "\(Constants.samplingIntervalSeconds)",
            "-n",
            "-x",
            "-J",
            "state,bytes_in,bytes_out",
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
            publishError(error.localizedDescription)
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
        sampleHandler = nil
        errorHandler = nil
        textBuffer = ""
        hasSeenBaselineSample = false
        currentSample.removeAll(keepingCapacity: false)
        currentProcessID = nil
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
        currentProcessID = nil

        publishError(errorMessage)
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

        if line.hasPrefix(",state,bytes_in,bytes_out") {
            finishCurrentSampleIfNeeded()
            currentSample.removeAll(keepingCapacity: true)
            currentProcessID = nil
            return
        }

        let fields = line
            .split(separator: ",", omittingEmptySubsequences: false)
            .map(String.init)

        guard let firstField = fields.first else { return }

        if let (processName, pid) = parseProcessIdentifier(firstField) {
            currentProcessID = pid
            currentSample[pid] = MutableProcessRecord(
                pid: pid,
                processName: processName,
                downloadBytesPerSecond: positiveNumber(at: 2, in: fields),
                uploadBytesPerSecond: positiveNumber(at: 3, in: fields),
                activeConnectionCount: 0,
                remoteHostCounts: [:],
                failureCountDelta: 0
            )
            return
        }

        guard let currentProcessID else { return }
        guard var record = currentSample[currentProcessID] else { return }

        let state = safeField(at: 1, in: fields)
        let remoteHost = extractRemoteHost(from: firstField)

        if let remoteHost {
            record.activeConnectionCount += 1
            record.remoteHostCounts[remoteHost, default: 0] += 1
        }

        if let state, isFailureLikeState(state) {
            record.failureCountDelta += 1
        }

        currentSample[currentProcessID] = record
    }

    private func finishCurrentSampleIfNeeded() {
        guard !currentSample.isEmpty else { return }

        if !hasSeenBaselineSample {
            hasSeenBaselineSample = true
            return
        }

        let sample = ProcessTrafficSample(
            sampleTime: Date(),
            processes: currentSample.values
                .map(\.sampleInput)
                .filter { process in
                    process.downloadBytesPerSecond >= Constants.minimumVisibleBytesPerSecond
                        || process.uploadBytesPerSecond >= Constants.minimumVisibleBytesPerSecond
                        || process.activeConnectionCount > 0
                        || process.failureCountDelta > 0
                }
        )

        publish(sample)
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

    private func safeField(at index: Int, in fields: [String]) -> String? {
        guard fields.indices.contains(index) else { return nil }

        let field = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return field.isEmpty ? nil : field
    }

    private func extractRemoteHost(from endpoint: String) -> String? {
        guard let arrowRange = endpoint.range(of: "<->") else { return nil }

        var remoteEndpoint = String(endpoint[arrowRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remoteEndpoint.isEmpty else { return nil }
        guard !remoteEndpoint.hasPrefix("*") else { return nil }

        if remoteEndpoint.contains("%"),
           let dotIndex = remoteEndpoint.lastIndex(of: ".") {
            remoteEndpoint = String(remoteEndpoint[..<dotIndex])
        } else if remoteEndpoint.filter({ $0 == ":" }).count <= 1,
                  let colonIndex = remoteEndpoint.lastIndex(of: ":") {
            remoteEndpoint = String(remoteEndpoint[..<colonIndex])
        }

        return remoteEndpoint.isEmpty ? nil : remoteEndpoint
    }

    private func isFailureLikeState(_ state: String) -> Bool {
        switch state.lowercased() {
        case "closewait", "lastack", "finwait1", "finwait2", "closed":
            return true
        default:
            return false
        }
    }

    private func publish(_ sample: ProcessTrafficSample) {
        guard let sampleHandler else { return }

        DispatchQueue.main.async {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier
            let enrichedProcesses = sample.processes.map { process in
                let runningApplication = NSRunningApplication(
                    processIdentifier: process.pid
                )
                let bundleIdentifier = runningApplication?.bundleIdentifier

                return ProcessTrafficSampleInput(
                    pid: process.pid,
                    processName: runningApplication?.localizedName ?? process.processName,
                    bundleIdentifier: bundleIdentifier,
                    isForegroundApp: bundleIdentifier == frontmostBundleIdentifier,
                    downloadBytesPerSecond: process.downloadBytesPerSecond,
                    uploadBytesPerSecond: process.uploadBytesPerSecond,
                    activeConnectionCount: process.activeConnectionCount,
                    remoteHostsTop: process.remoteHostsTop,
                    failureCountDelta: process.failureCountDelta
                )
            }

            sampleHandler(
                ProcessTrafficSample(
                    sampleTime: sample.sampleTime,
                    processes: enrichedProcesses
                )
            )
        }
    }

    private func publishError(_ message: String) {
        guard let errorHandler else { return }

        DispatchQueue.main.async {
            errorHandler(message)
        }
    }
}
