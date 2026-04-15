//
//  NetworkMonitor.swift
//  vm-net
//
//  Created by chen on 2025/4/4.
//

import Foundation

final class NetworkMonitor {

    private let countersReader: NetworkCountersReading
    private let samplingInterval: TimeInterval
    private let smoothingFactor: Double
    private let displayDeadbandBytesPerSecond: Double
    private let displayDeadbandRatio: Double
    private let historyLimit: Int
    private let queue: DispatchQueue

    private var lastCounters: NetworkCountersSnapshot?
    private var displayedThroughput: NetworkThroughput = .zero
    private var history: [NetworkThroughput] = []
    private var timer: DispatchSourceTimer?

    var updateHandler: ((NetworkMonitorSnapshot) -> Void)?

    init(
        countersReader: NetworkCountersReading = SystemNetworkCountersReader(),
        samplingInterval: TimeInterval = 1.0,
        smoothingFactor: Double = 0.35,
        displayDeadbandBytesPerSecond: Double = 512,
        displayDeadbandRatio: Double = 0.12,
        historyLimit: Int = 18,
        queue: DispatchQueue = DispatchQueue(
            label: "cn.tpshion.vm-net.network-monitor"
        )
    ) {
        self.countersReader = countersReader
        self.samplingInterval = samplingInterval
        self.smoothingFactor = smoothingFactor
        self.displayDeadbandBytesPerSecond = displayDeadbandBytesPerSecond
        self.displayDeadbandRatio = displayDeadbandRatio
        self.historyLimit = historyLimit
        self.queue = queue
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard timer == nil else { return }

        lastCounters = countersReader.readSnapshot()
        publish(
            snapshot: NetworkMonitorSnapshot(
                monitoredInterfaceName: lastCounters?.interfaceDisplayName,
                instantaneousThroughput: .zero,
                displayedThroughput: .zero,
                history: history,
                lastUpdatedAt: lastCounters?.timestamp
            )
        )

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + samplingInterval,
            repeating: samplingInterval,
            leeway: .milliseconds(120)
        )
        timer.setEventHandler { [weak self] in
            self?.sampleAndPublish()
        }
        self.timer = timer
        timer.resume()
    }

    func stopMonitoring() {
        guard let timer else { return }

        timer.setEventHandler(handler: {})
        timer.cancel()

        self.timer = nil
        lastCounters = nil
        displayedThroughput = .zero
        history.removeAll(keepingCapacity: true)
    }

    private func sampleAndPublish() {
        guard let currentCounters = countersReader.readSnapshot() else {
            resetPublishedState(
                interfaceName: nil,
                lastUpdatedAt: nil
            )
            return
        }

        guard let previousCounters = lastCounters else {
            lastCounters = currentCounters
            resetPublishedState(
                interfaceName: currentCounters.interfaceDisplayName,
                lastUpdatedAt: currentCounters.timestamp
            )
            return
        }

        guard currentCounters.matchesInterface(with: previousCounters) else {
            lastCounters = currentCounters
            resetPublishedState(
                interfaceName: currentCounters.interfaceDisplayName,
                lastUpdatedAt: currentCounters.timestamp
            )
            return
        }

        lastCounters = currentCounters

        let instantaneous = currentCounters.throughput(since: previousCounters)
        let previousDisplayedThroughput = displayedThroughput
        let smoothedThroughput = instantaneous.smoothed(
            against: previousDisplayedThroughput,
            factor: smoothingFactor
        )
        displayedThroughput = smoothedThroughput.stabilized(
            against: previousDisplayedThroughput,
            minimumDelta: displayDeadbandBytesPerSecond,
            relativeDelta: displayDeadbandRatio
        )
        appendToHistory(displayedThroughput)

        publish(
            snapshot: NetworkMonitorSnapshot(
                monitoredInterfaceName: currentCounters.interfaceDisplayName,
                instantaneousThroughput: instantaneous,
                displayedThroughput: displayedThroughput,
                history: history,
                lastUpdatedAt: currentCounters.timestamp
            )
        )
    }

    private func resetPublishedState(
        interfaceName: String?,
        lastUpdatedAt: Date?
    ) {
        displayedThroughput = .zero
        history.removeAll(keepingCapacity: true)

        publish(
            snapshot: NetworkMonitorSnapshot(
                monitoredInterfaceName: interfaceName,
                instantaneousThroughput: .zero,
                displayedThroughput: .zero,
                history: history,
                lastUpdatedAt: lastUpdatedAt
            )
        )
    }

    private func appendToHistory(_ throughput: NetworkThroughput) {
        history.append(throughput)

        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }

    private func publish(snapshot: NetworkMonitorSnapshot) {
        let handler = updateHandler

        DispatchQueue.main.async {
            handler?(snapshot)
        }
    }
}
