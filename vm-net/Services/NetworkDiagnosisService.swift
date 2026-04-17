//
//  NetworkDiagnosisService.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Darwin
import Foundation
import Network

actor NetworkDiagnosisService {

    struct Progress: Sendable {
        let phase: NetworkDiagnosisPhase
        let statusMessage: String
        let targetHost: String
        let checks: [NetworkDiagnosisCheck]
        let updatedAt: Date
    }

    private struct PathInfo {
        let status: NWPath.Status
        let interfaceSummary: String
        let isExpensive: Bool
        let isConstrained: Bool
    }

    private struct DNSInfo {
        let success: Bool
        let latencyMilliseconds: Double?
        let addresses: [String]
        let errorDescription: String?
    }

    private struct HTTPSInfo {
        let success: Bool
        let latencyMilliseconds: Double?
        let statusCode: Int?
        let errorDescription: String?
    }

    private enum Constants {
        static let pathTimeoutNanoseconds: UInt64 = 4_000_000_000
        static let dnsTimeoutNanoseconds: UInt64 = 5_000_000_000
        static let httpsTimeout: TimeInterval = 12
        static let dnsWarningThresholdMilliseconds = 220.0
        static let httpsWarningThresholdMilliseconds = 1_500.0
    }

    private enum ServiceError: LocalizedError {
        case pathTimeout
        case invalidTarget

        var errorDescription: String? {
            switch self {
            case .pathTimeout:
                return L10n.tr("diagnosis.error.pathTimeout")
            case .invalidTarget:
                return L10n.tr("diagnosis.error.invalidTarget")
            }
        }
    }

    private let sessionConfiguration: URLSessionConfiguration

    init(sessionConfiguration: URLSessionConfiguration = .ephemeral) {
        sessionConfiguration.waitsForConnectivity = false
        sessionConfiguration.timeoutIntervalForRequest = Constants.httpsTimeout
        sessionConfiguration.timeoutIntervalForResource = Constants.httpsTimeout
        self.sessionConfiguration = sessionConfiguration
    }

    func run(
        target: String,
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> NetworkDiagnosisResult {
        let startedAt = Date()
        let targetURL = try Self.normalizedURL(from: target)
        let targetHost = targetURL.host ?? target
        var checks: [NetworkDiagnosisCheck] = []

        progressHandler(
            Progress(
                phase: .checkingPath,
                statusMessage: L10n.tr("diagnosis.progress.checkingPath"),
                targetHost: targetHost,
                checks: checks,
                updatedAt: startedAt
            )
        )

        try Task.checkCancellation()
        let pathInfo = try await currentPathInfo()
        let pathCheck = makePathCheck(from: pathInfo)
        checks.append(pathCheck)
        progressHandler(
            Progress(
                phase: .checkingPath,
                statusMessage: pathCheck.summary,
                targetHost: targetHost,
                checks: checks,
                updatedAt: Date()
            )
        )

        guard pathInfo.status == .satisfied else {
            let dnsSkipped = skippedCheck(
                kind: .dns,
                reason: L10n.tr("diagnosis.reason.skipDNSForUnavailablePath")
            )
            let httpsSkipped = skippedCheck(
                kind: .https,
                reason: L10n.tr("diagnosis.reason.skipHTTPSForUnavailablePath")
            )
            checks.append(contentsOf: [dnsSkipped, httpsSkipped])

            return makeResult(
                targetHost: targetHost,
                checks: checks,
                dnsLatencyMilliseconds: nil,
                httpsLatencyMilliseconds: nil,
                httpStatusCode: nil,
                startedAt: startedAt,
                finishedAt: Date()
            )
        }

        progressHandler(
            Progress(
                phase: .resolvingDNS,
                statusMessage: L10n.tr("diagnosis.progress.resolvingHost", targetHost),
                targetHost: targetHost,
                checks: checks,
                updatedAt: Date()
            )
        )

        try Task.checkCancellation()
        let dnsInfo = await resolveDNS(host: targetHost)
        let dnsCheck = makeDNSCheck(from: dnsInfo, targetHost: targetHost)
        checks.append(dnsCheck)
        progressHandler(
            Progress(
                phase: .resolvingDNS,
                statusMessage: dnsCheck.summary,
                targetHost: targetHost,
                checks: checks,
                updatedAt: Date()
            )
        )

        guard dnsInfo.success else {
            let httpsSkipped = skippedCheck(
                kind: .https,
                reason: L10n.tr("diagnosis.reason.skipHTTPSForDNSFailure")
            )
            checks.append(httpsSkipped)

            return makeResult(
                targetHost: targetHost,
                checks: checks,
                dnsLatencyMilliseconds: dnsInfo.latencyMilliseconds,
                httpsLatencyMilliseconds: nil,
                httpStatusCode: nil,
                startedAt: startedAt,
                finishedAt: Date()
            )
        }

        progressHandler(
            Progress(
                phase: .checkingHTTPS,
                statusMessage: L10n.tr("diagnosis.progress.checkingHTTPS"),
                targetHost: targetHost,
                checks: checks,
                updatedAt: Date()
            )
        )

        try Task.checkCancellation()
        let httpsInfo = await probeHTTPS(url: targetURL)
        let httpsCheck = makeHTTPSCheck(from: httpsInfo, targetHost: targetHost)
        checks.append(httpsCheck)
        progressHandler(
            Progress(
                phase: .checkingHTTPS,
                statusMessage: httpsCheck.summary,
                targetHost: targetHost,
                checks: checks,
                updatedAt: Date()
            )
        )

        return makeResult(
            targetHost: targetHost,
            checks: checks,
            dnsLatencyMilliseconds: dnsInfo.latencyMilliseconds,
            httpsLatencyMilliseconds: httpsInfo.latencyMilliseconds,
            httpStatusCode: httpsInfo.statusCode,
            startedAt: startedAt,
            finishedAt: Date()
        )
    }

    private func currentPathInfo() async throws -> PathInfo {
        try await withThrowingTaskGroup(of: PathInfo.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    let monitor = NWPathMonitor()
                    let queue = DispatchQueue(label: "cn.tpshion.vm-net.diagnosis.path")

                    monitor.pathUpdateHandler = { path in
                        let summary = Self.interfaceSummary(for: path)
                        continuation.resume(
                            returning: PathInfo(
                                status: path.status,
                                interfaceSummary: summary,
                                isExpensive: path.isExpensive,
                                isConstrained: path.isConstrained
                            )
                        )
                        monitor.cancel()
                    }

                    monitor.start(queue: queue)
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: Constants.pathTimeoutNanoseconds)
                throw ServiceError.pathTimeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func resolveDNS(host: String) async -> DNSInfo {
        await withTaskGroup(of: DNSInfo.self) { group in
            group.addTask {
                let startedAt = Date()
                return await Task.detached(priority: .utility) {
                    var hints = addrinfo(
                        ai_flags: Int32(AI_DEFAULT),
                        ai_family: AF_UNSPEC,
                        ai_socktype: Int32(SOCK_STREAM),
                        ai_protocol: IPPROTO_TCP,
                        ai_addrlen: 0,
                        ai_canonname: nil,
                        ai_addr: nil,
                        ai_next: nil
                    )
                    var infoPointer: UnsafeMutablePointer<addrinfo>?
                    let result = getaddrinfo(host, nil, &hints, &infoPointer)

                    guard result == 0 else {
                        return DNSInfo(
                            success: false,
                            latencyMilliseconds: nil,
                            addresses: [],
                            errorDescription: String(cString: gai_strerror(result))
                        )
                    }

                    defer {
                        if let infoPointer {
                            freeaddrinfo(infoPointer)
                        }
                    }

                    var addresses: [String] = []
                    var current = infoPointer
                    while let entry = current {
                        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let getNameResult = getnameinfo(
                            entry.pointee.ai_addr,
                            entry.pointee.ai_addrlen,
                            &hostBuffer,
                            socklen_t(hostBuffer.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        )

                        if getNameResult == 0 {
                            let address = String(cString: hostBuffer)
                            if !addresses.contains(address) {
                                addresses.append(address)
                            }
                        }

                        current = entry.pointee.ai_next
                    }

                    return DNSInfo(
                        success: !addresses.isEmpty,
                        latencyMilliseconds: Date().timeIntervalSince(startedAt) * 1_000,
                        addresses: Array(addresses.prefix(3)),
                        errorDescription: addresses.isEmpty ? L10n.tr("diagnosis.error.noUsableAddress") : nil
                    )
                }.value
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: Constants.dnsTimeoutNanoseconds)
                return DNSInfo(
                    success: false,
                    latencyMilliseconds: nil,
                    addresses: [],
                    errorDescription: L10n.tr("diagnosis.error.dnsTimeout")
                )
            }

            let first = await group.next() ?? DNSInfo(
                success: false,
                latencyMilliseconds: nil,
                addresses: [],
                errorDescription: L10n.tr("diagnosis.error.dnsFailure")
            )
            group.cancelAll()
            return first
        }
    }

    private func probeHTTPS(url: URL) async -> HTTPSInfo {
        let delegate = HTTPSMetricsCollector()
        let session = URLSession(
            configuration: sessionConfiguration,
            delegate: delegate,
            delegateQueue: nil
        )
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = Constants.httpsTimeout
        request.httpMethod = "GET"
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        defer {
            session.invalidateAndCancel()
        }

        do {
            let (_, response) = try await session.data(for: request, delegate: delegate)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let latency = delegate.totalLatencyMilliseconds
            let success = (statusCode.map { (200..<400).contains($0) } ?? true)

            return HTTPSInfo(
                success: success,
                latencyMilliseconds: latency,
                statusCode: statusCode,
                errorDescription: success ? nil : L10n.tr("diagnosis.error.badHTTPStatus")
            )
        } catch {
            return HTTPSInfo(
                success: false,
                latencyMilliseconds: delegate.totalLatencyMilliseconds,
                statusCode: nil,
                errorDescription: error.localizedDescription
            )
        }
    }

    private func makePathCheck(from info: PathInfo) -> NetworkDiagnosisCheck {
        guard info.status == .satisfied else {
            return NetworkDiagnosisCheck(
                kind: .path,
                status: .failure,
                summary: L10n.tr("diagnosis.path.failure.summary"),
                detail: L10n.tr("diagnosis.path.failure.detail")
            )
        }

        if info.isConstrained || info.isExpensive {
            return NetworkDiagnosisCheck(
                kind: .path,
                status: .warning,
                summary: L10n.tr("diagnosis.path.warning.summary"),
                detail: pathDetail(from: info)
            )
        }

        return NetworkDiagnosisCheck(
            kind: .path,
            status: .success,
            summary: L10n.tr("diagnosis.path.success.summary"),
            detail: pathDetail(from: info)
        )
    }

    private func makeDNSCheck(from info: DNSInfo, targetHost: String) -> NetworkDiagnosisCheck {
        guard info.success else {
            return NetworkDiagnosisCheck(
                kind: .dns,
                status: .failure,
                summary: L10n.tr("diagnosis.dns.failure.summary", targetHost),
                detail: info.errorDescription
            )
        }

        let addressText = info.addresses.joined(separator: L10n.tr("common.listSeparator"))
        let detail = [formattedLatency(info.latencyMilliseconds), addressText]
            .filter { !$0.isEmpty }
            .joined(separator: L10n.tr("common.detailSeparator"))

        if let latency = info.latencyMilliseconds,
           latency >= Constants.dnsWarningThresholdMilliseconds {
            return NetworkDiagnosisCheck(
                kind: .dns,
                status: .warning,
                summary: L10n.tr("diagnosis.dns.warning.summary", targetHost),
                detail: detail
            )
        }

        return NetworkDiagnosisCheck(
            kind: .dns,
            status: .success,
            summary: L10n.tr("diagnosis.dns.success.summary", targetHost),
            detail: detail
        )
    }

    private func makeHTTPSCheck(from info: HTTPSInfo, targetHost: String) -> NetworkDiagnosisCheck {
        guard info.success else {
            let detail = [
                formattedLatency(info.latencyMilliseconds),
                info.statusCode.map { L10n.tr("common.httpStatusCode", $0) },
                info.errorDescription
            ]
            .compactMap { $0 }
            .joined(separator: L10n.tr("common.detailSeparator"))

            return NetworkDiagnosisCheck(
                kind: .https,
                status: .failure,
                summary: L10n.tr("diagnosis.https.failure.summary", targetHost),
                detail: detail.isEmpty ? nil : detail
            )
        }

        let detail = [
            formattedLatency(info.latencyMilliseconds),
            info.statusCode.map { L10n.tr("common.httpStatusCode", $0) }
        ]
        .compactMap { $0 }
        .joined(separator: L10n.tr("common.detailSeparator"))

        if let latency = info.latencyMilliseconds,
           latency >= Constants.httpsWarningThresholdMilliseconds {
            return NetworkDiagnosisCheck(
                kind: .https,
                status: .warning,
                summary: L10n.tr("diagnosis.https.warning.summary"),
                detail: detail
            )
        }

        return NetworkDiagnosisCheck(
            kind: .https,
            status: .success,
            summary: L10n.tr("diagnosis.https.success.summary"),
            detail: detail
        )
    }

    private func skippedCheck(
        kind: NetworkDiagnosisCheckKind,
        reason: String
    ) -> NetworkDiagnosisCheck {
        NetworkDiagnosisCheck(
            kind: kind,
            status: .skipped,
            summary: L10n.tr("diagnosis.check.skipped.summary", kind.title),
            detail: reason
        )
    }

    private func makeResult(
        targetHost: String,
        checks: [NetworkDiagnosisCheck],
        dnsLatencyMilliseconds: Double?,
        httpsLatencyMilliseconds: Double?,
        httpStatusCode: Int?,
        startedAt: Date,
        finishedAt: Date
    ) -> NetworkDiagnosisResult {
        let overallStatus = if checks.contains(where: { $0.status == .failure }) {
            NetworkDiagnosisCheckStatus.failure
        } else if checks.contains(where: { $0.status == .warning }) {
            NetworkDiagnosisCheckStatus.warning
        } else {
            NetworkDiagnosisCheckStatus.success
        }

        let problematicCheck = checks.first(where: { $0.status == .failure })
            ?? checks.first(where: { $0.status == .warning })

        let headline: String
        let summary: String

        switch overallStatus {
        case .success:
            headline = L10n.tr("diagnosis.result.success.headline")
            summary = L10n.tr("diagnosis.result.success.summary")
        case .warning:
            headline = problematicCheck?.summary ?? L10n.tr("diagnosis.result.warning.headlineFallback")
            summary = problematicCheck?.detail ?? L10n.tr("diagnosis.result.warning.summaryFallback")
        case .failure:
            headline = problematicCheck?.summary ?? L10n.tr("diagnosis.result.failure.headlineFallback")
            summary = problematicCheck?.detail ?? L10n.tr("diagnosis.result.failure.summaryFallback")
        case .skipped:
            headline = L10n.tr("diagnosis.result.skipped.headline")
            summary = L10n.tr("diagnosis.result.skipped.summary")
        }

        return NetworkDiagnosisResult(
            targetHost: targetHost,
            overallStatus: overallStatus,
            headline: headline,
            summary: summary,
            checks: checks,
            dnsLatencyMilliseconds: dnsLatencyMilliseconds,
            httpsLatencyMilliseconds: httpsLatencyMilliseconds,
            httpStatusCode: httpStatusCode,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    private func pathDetail(from info: PathInfo) -> String {
        var parts = [info.interfaceSummary]

        if info.isExpensive {
            parts.append(L10n.tr("diagnosis.pathDetail.expensive"))
        }

        if info.isConstrained {
            parts.append(L10n.tr("diagnosis.pathDetail.constrained"))
        }

        return parts.joined(separator: L10n.tr("common.detailSeparator"))
    }

    private func formattedLatency(_ latency: Double?) -> String {
        guard let latency else { return "" }
        return String(format: "%.0fms", latency.rounded())
    }

    private static func interfaceSummary(for path: NWPath) -> String {
        var interfaces: [String] = []

        if path.usesInterfaceType(.wifi) {
            interfaces.append("Wi‑Fi")
        }
        if path.usesInterfaceType(.wiredEthernet) {
            interfaces.append(L10n.tr("diagnosis.interface.wired"))
        }
        if path.usesInterfaceType(.cellular) {
            interfaces.append(L10n.tr("diagnosis.interface.cellular"))
        }
        if path.usesInterfaceType(.other) {
            interfaces.append(L10n.tr("diagnosis.interface.other"))
        }

        return interfaces.isEmpty
            ? L10n.tr("diagnosis.interface.unknown")
            : interfaces.joined(separator: " / ")
    }

    private static func normalizedURL(from target: String) throws -> URL {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.invalidTarget
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate) else {
            throw ServiceError.invalidTarget
        }

        if components.scheme?.lowercased() != "https" {
            components.scheme = "https"
        }

        guard let host = components.host, !host.isEmpty else {
            throw ServiceError.invalidTarget
        }

        if components.path.isEmpty {
            components.path = "/"
        }

        guard let url = components.url, url.host == host else {
            throw ServiceError.invalidTarget
        }

        return url
    }
}

private final class HTTPSMetricsCollector: NSObject, URLSessionTaskDelegate {
    private let lock = NSLock()
    private var metrics: URLSessionTaskMetrics?

    var totalLatencyMilliseconds: Double? {
        lock.lock()
        defer { lock.unlock() }

        guard
            let transaction = metrics?.transactionMetrics.last,
            let start = transaction.fetchStartDate,
            let end = transaction.responseEndDate
        else {
            return nil
        }

        return end.timeIntervalSince(start) * 1_000
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        lock.lock()
        self.metrics = metrics
        lock.unlock()
    }
}
