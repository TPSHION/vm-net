//
//  MLabSpeedTestService.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import Foundation

actor MLabSpeedTestService {

    struct Progress: Sendable {
        let phase: SpeedTestPhase
        let statusMessage: String
        let serverName: String?
        let latencyMilliseconds: Double?
        let downloadMbps: Double?
        let uploadMbps: Double?
        let updatedAt: Date
    }

    private struct LocatedServer {
        let name: String
        let downloadURL: URL
        let uploadURL: URL
    }

    private struct TestSample {
        let throughputMbps: Double
        let latencyMilliseconds: Double?
    }

    private struct ReceiveSummary {
        var throughputMbps: Double?
        var latencyMilliseconds: Double?
    }

    private struct LocateResponse: Decodable {
        let results: [LocateServer]
    }

    private struct LocateServer: Decodable {
        let machine: String
        let location: Location?
        let urls: URLs
    }

    private struct Location: Decodable {
        let country: String?
        let city: String?
    }

    private struct URLs: Decodable {
        let downloadPath: String
        let uploadPath: String

        enum CodingKeys: String, CodingKey {
            case downloadPath = "wss:///ndt/v7/download"
            case uploadPath = "wss:///ndt/v7/upload"
        }
    }

    private struct Measurement: Decodable {
        let appInfo: AppInfo?
        let tcpInfo: TCPInfo?

        enum CodingKeys: String, CodingKey {
            case appInfo = "AppInfo"
            case tcpInfo = "TCPInfo"
        }
    }

    private struct AppInfo: Decodable {
        let elapsedTime: Int64?
        let numBytes: Int64?

        enum CodingKeys: String, CodingKey {
            case elapsedTime = "ElapsedTime"
            case numBytes = "NumBytes"
        }

        var throughputMbps: Double? {
            guard
                let elapsedTime,
                let numBytes,
                elapsedTime > 0,
                numBytes >= 0
            else {
                return nil
            }

            return Double(numBytes) * 8 * 1_000_000 / Double(elapsedTime) / 1_000_000
        }
    }

    private struct TCPInfo: Decodable {
        let minRTT: Int64?
        let rtt: Int64?

        enum CodingKeys: String, CodingKey {
            case minRTT = "MinRTT"
            case rtt = "RTT"
        }

        var latencyMilliseconds: Double? {
            if let minRTT, minRTT > 0 {
                return Double(minRTT) / 1_000
            }

            guard let rtt, rtt > 0 else { return nil }
            return Double(rtt) / 1_000
        }
    }

    private enum ServiceError: LocalizedError {
        case noAvailableServer
        case invalidServerResponse
        case invalidServerURL

        var errorDescription: String? {
            switch self {
            case .noAvailableServer:
                return "未找到可用的 M-Lab 节点。"
            case .invalidServerResponse:
                return "M-Lab 返回了无法识别的测速数据。"
            case .invalidServerURL:
                return "M-Lab 节点地址无效。"
            }
        }
    }

    private enum Constants {
        static let protocolName = "net.measurementlab.ndt.v7"
        static let locateURL = URL(
            string: "https://locate.measurementlab.net/v2/nearest/ndt/ndt7?client_name=vm-net"
        )!
        static let downloadDuration: TimeInterval = 8
        static let uploadDuration: TimeInterval = 6
        static let requestTimeout: TimeInterval = 20
        static let updateInterval: TimeInterval = 0.25
        static let uploadChunkSize = 1 << 16
        static let maximumFallbackServers = 3
    }

    private let session: URLSession
    private var activeDownloadTask: URLSessionWebSocketTask?
    private var activeUploadTask: URLSessionWebSocketTask?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func run(
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> SpeedTestResult {
        try await withTaskCancellationHandler {
            let startedAt = Date()
            progressHandler(
                Progress(
                    phase: .locatingServer,
                    statusMessage: "正在选择 M-Lab 节点…",
                    serverName: nil,
                    latencyMilliseconds: nil,
                    downloadMbps: nil,
                    uploadMbps: nil,
                    updatedAt: startedAt
                )
            )

            let candidates = try await locateServers()
            let servers = Array(candidates.prefix(Constants.maximumFallbackServers))
            var lastError: Error?

            for (index, server) in servers.enumerated() {
                do {
                    progressHandler(
                        Progress(
                            phase: .locatingServer,
                            statusMessage: "已连接 \(server.name)",
                            serverName: server.name,
                            latencyMilliseconds: nil,
                            downloadMbps: nil,
                            uploadMbps: nil,
                            updatedAt: Date()
                        )
                    )

                    let downloadSample = try await runDownloadTest(
                        on: server,
                        progressHandler: progressHandler
                    )
                    let uploadSample = try await runUploadTest(
                        on: server,
                        initialLatencyMilliseconds: downloadSample.latencyMilliseconds,
                        progressHandler: progressHandler
                    )
                    let result = SpeedTestResult(
                        serverName: server.name,
                        latencyMilliseconds: uploadSample.latencyMilliseconds
                            ?? downloadSample.latencyMilliseconds,
                        downloadMbps: downloadSample.throughputMbps,
                        uploadMbps: uploadSample.throughputMbps,
                        startedAt: startedAt,
                        finishedAt: Date()
                    )

                    progressHandler(
                        Progress(
                            phase: .completed,
                            statusMessage: "测速完成",
                            serverName: result.serverName,
                            latencyMilliseconds: result.latencyMilliseconds,
                            downloadMbps: result.downloadMbps,
                            uploadMbps: result.uploadMbps,
                            updatedAt: result.finishedAt
                        )
                    )

                    return result
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastError = error
                    cancel()

                    if index < servers.count - 1 {
                        progressHandler(
                            Progress(
                                phase: .locatingServer,
                                statusMessage: "当前节点不可用，正在切换备用节点…",
                                serverName: server.name,
                                latencyMilliseconds: nil,
                                downloadMbps: nil,
                                uploadMbps: nil,
                                updatedAt: Date()
                            )
                        )
                    }
                }
            }

            throw lastError ?? ServiceError.noAvailableServer
        } onCancel: {
            Task {
                await self.cancel()
            }
        }
    }

    func cancel() {
        activeDownloadTask?.cancel(with: .goingAway, reason: nil)
        activeUploadTask?.cancel(with: .goingAway, reason: nil)
        activeDownloadTask = nil
        activeUploadTask = nil
    }

    private func locateServers() async throws -> [LocatedServer] {
        let request = URLRequest(
            url: Constants.locateURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Constants.requestTimeout
        )
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(LocateResponse.self, from: data)

        let servers = try response.results.map { server in
            guard
                let downloadURL = URL(string: server.urls.downloadPath),
                let uploadURL = URL(string: server.urls.uploadPath)
            else {
                throw ServiceError.invalidServerURL
            }

            return LocatedServer(
                name: Self.serverDisplayName(for: server),
                downloadURL: downloadURL,
                uploadURL: uploadURL
            )
        }

        guard !servers.isEmpty else {
            throw ServiceError.noAvailableServer
        }

        return servers
    }

    private func runDownloadTest(
        on server: LocatedServer,
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> TestSample {
        let task = makeWebSocketTask(url: server.downloadURL)
        activeDownloadTask = task
        task.resume()

        let startedAt = Date()
        var receivedBytes = 0
        var lastProgressAt = startedAt
        var lastReportedMbps: Double?
        var lastLatencyMilliseconds: Double?

        progressHandler(
            Progress(
                phase: .measuringDownload,
                statusMessage: "正在测试下载…",
                serverName: server.name,
                latencyMilliseconds: nil,
                downloadMbps: nil,
                uploadMbps: nil,
                updatedAt: startedAt
            )
        )

        defer {
            task.cancel(with: .normalClosure, reason: nil)
            activeDownloadTask = nil
        }

        while Date().timeIntervalSince(startedAt) < Constants.downloadDuration {
            try Task.checkCancellation()

            let message = try await task.receive()
            let now = Date()

            switch message {
            case .data(let data):
                receivedBytes += data.count
            case .string(let text):
                let measurement = try decodeMeasurement(from: text)
                lastReportedMbps = measurement.appInfo?.throughputMbps ?? lastReportedMbps
                lastLatencyMilliseconds = measurement.tcpInfo?.latencyMilliseconds
                    ?? lastLatencyMilliseconds
            @unknown default:
                break
            }

            if now.timeIntervalSince(lastProgressAt) >= Constants.updateInterval {
                let clientMbps = Self.throughputMbps(
                    bytes: receivedBytes,
                    elapsed: now.timeIntervalSince(startedAt)
                )
                progressHandler(
                    Progress(
                        phase: .measuringDownload,
                        statusMessage: "正在测试下载…",
                        serverName: server.name,
                        latencyMilliseconds: lastLatencyMilliseconds,
                        downloadMbps: lastReportedMbps ?? clientMbps,
                        uploadMbps: nil,
                        updatedAt: now
                    )
                )
                lastProgressAt = now
            }
        }

        let clientMbps = Self.throughputMbps(
            bytes: receivedBytes,
            elapsed: Date().timeIntervalSince(startedAt)
        )
        return TestSample(
            throughputMbps: lastReportedMbps ?? clientMbps,
            latencyMilliseconds: lastLatencyMilliseconds
        )
    }

    private func runUploadTest(
        on server: LocatedServer,
        initialLatencyMilliseconds: Double?,
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> TestSample {
        let task = makeWebSocketTask(url: server.uploadURL)
        activeUploadTask = task
        task.resume()

        let startedAt = Date()
        let payload = Data((0..<Constants.uploadChunkSize).map { _ in
            UInt8.random(in: 0...255)
        })
        var sentBytes = 0
        var lastProgressAt = startedAt
        var receiveSummary = ReceiveSummary(
            throughputMbps: nil,
            latencyMilliseconds: initialLatencyMilliseconds
        )

        progressHandler(
            Progress(
                phase: .measuringUpload,
                statusMessage: "正在测试上传…",
                serverName: server.name,
                latencyMilliseconds: initialLatencyMilliseconds,
                downloadMbps: nil,
                uploadMbps: nil,
                updatedAt: startedAt
            )
        )

        let receiver = Task<ReceiveSummary, Never> {
            var summary = receiveSummary

            while !Task.isCancelled {
                do {
                    let message = try await task.receive()

                    switch message {
                    case .string(let text):
                        let measurement = try decodeMeasurement(from: text)
                        summary.throughputMbps = measurement.appInfo?.throughputMbps
                            ?? summary.throughputMbps
                        summary.latencyMilliseconds = measurement.tcpInfo?.latencyMilliseconds
                            ?? summary.latencyMilliseconds
                    case .data:
                        continue
                    @unknown default:
                        continue
                    }
                } catch {
                    return summary
                }
            }

            return summary
        }

        defer {
            task.cancel(with: .normalClosure, reason: nil)
            receiver.cancel()
            activeUploadTask = nil
        }

        while Date().timeIntervalSince(startedAt) < Constants.uploadDuration {
            try Task.checkCancellation()

            try await task.send(.data(payload))
            sentBytes += payload.count

            let now = Date()
            if now.timeIntervalSince(lastProgressAt) >= Constants.updateInterval {
                let clientMbps = Self.throughputMbps(
                    bytes: sentBytes,
                    elapsed: now.timeIntervalSince(startedAt)
                )
                progressHandler(
                    Progress(
                        phase: .measuringUpload,
                        statusMessage: "正在测试上传…",
                        serverName: server.name,
                        latencyMilliseconds: receiveSummary.latencyMilliseconds,
                        downloadMbps: nil,
                        uploadMbps: receiveSummary.throughputMbps ?? clientMbps,
                        updatedAt: now
                    )
                )
                lastProgressAt = now
            }
        }

        task.cancel(with: .normalClosure, reason: nil)
        receiveSummary = await receiver.value

        let clientMbps = Self.throughputMbps(
            bytes: sentBytes,
            elapsed: Date().timeIntervalSince(startedAt)
        )
        return TestSample(
            throughputMbps: receiveSummary.throughputMbps ?? clientMbps,
            latencyMilliseconds: receiveSummary.latencyMilliseconds
        )
    }

    private func makeWebSocketTask(url: URL) -> URLSessionWebSocketTask {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Constants.requestTimeout
        )
        request.setValue(
            Constants.protocolName,
            forHTTPHeaderField: "Sec-WebSocket-Protocol"
        )
        return session.webSocketTask(with: request)
    }

    private func decodeMeasurement(from text: String) throws -> Measurement {
        guard let data = text.data(using: .utf8) else {
            throw ServiceError.invalidServerResponse
        }

        return try JSONDecoder().decode(Measurement.self, from: data)
    }

    private static func throughputMbps(bytes: Int, elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return 0 }
        return Double(bytes) * 8 / elapsed / 1_000_000
    }

    private static func serverDisplayName(for server: LocateServer) -> String {
        var components: [String] = []

        if let city = server.location?.city, !city.isEmpty {
            components.append(city)
        }

        if let country = server.location?.country, !country.isEmpty {
            components.append(country)
        }

        return components.isEmpty
            ? server.machine
            : components.joined(separator: ", ")
    }
}
