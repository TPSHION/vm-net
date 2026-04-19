import Foundation

private struct TestFailure: Error {
    let message: String
}

@main
struct ProcessTrafficActivityDeriverTestsRunner {

    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("accumulates 10-second and 1-minute traffic", testRollingWindows),
            ("keeps recent quiet processes visible in the 1-minute window", testQuietProcessRetention),
            ("adds burst and retry-like tags from recent samples", testTags),
        ]

        var failures: [String] = []

        for (name, test) in tests {
            do {
                try test()
                print("PASS \(name)")
            } catch {
                failures.append("FAIL \(name): \(error)")
                print("FAIL \(name): \(error)")
            }
        }

        if !failures.isEmpty {
            fputs("\n\(failures.joined(separator: "\n"))\n", stderr)
            exit(1)
        }
    }

    private static func testRollingWindows() throws {
        let deriver = ProcessTrafficActivityDeriver()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        let firstSample = ProcessTrafficSample(
            sampleTime: baseDate,
            processes: [
                ProcessTrafficSampleInput(
                    pid: 42,
                    processName: "Google Chrome",
                    bundleIdentifier: "com.google.Chrome",
                    isForegroundApp: false,
                    downloadBytesPerSecond: 2 * 1024 * 1024,
                    uploadBytesPerSecond: 128 * 1024,
                    activeConnectionCount: 6,
                    remoteHostsTop: ["googlevideo.com"],
                    failureCountDelta: 0
                )
            ]
        )
        let secondSample = ProcessTrafficSample(
            sampleTime: baseDate.addingTimeInterval(1),
            processes: [
                ProcessTrafficSampleInput(
                    pid: 42,
                    processName: "Google Chrome",
                    bundleIdentifier: "com.google.Chrome",
                    isForegroundApp: false,
                    downloadBytesPerSecond: 1 * 1024 * 1024,
                    uploadBytesPerSecond: 256 * 1024,
                    activeConnectionCount: 8,
                    remoteHostsTop: ["googlevideo.com", "youtube.com"],
                    failureCountDelta: 0
                )
            ]
        )

        _ = deriver.derive(sample: firstSample)
        let records = deriver.derive(sample: secondSample)
        let record = try requireRecord(pid: 42, in: records)

        try expectEqual(record.downloadBytesPerSecond, 1 * 1024 * 1024)
        try expectEqual(record.tenSecondDownloadBytes, 3 * 1024 * 1024)
        try expectEqual(record.oneMinuteUploadBytes, 384 * 1024)
        try expectEqual(record.activeConnectionCount, 8)
    }

    private static func testQuietProcessRetention() throws {
        let deriver = ProcessTrafficActivityDeriver()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_100)

        let firstSample = ProcessTrafficSample(
            sampleTime: baseDate,
            processes: [
                ProcessTrafficSampleInput(
                    pid: 7,
                    processName: "Dropbox",
                    bundleIdentifier: "com.getdropbox.dropbox",
                    isForegroundApp: false,
                    downloadBytesPerSecond: 512 * 1024,
                    uploadBytesPerSecond: 512 * 1024,
                    activeConnectionCount: 3,
                    remoteHostsTop: ["dropbox.com"],
                    failureCountDelta: 0
                )
            ]
        )
        let quietSample = ProcessTrafficSample(
            sampleTime: baseDate.addingTimeInterval(5),
            processes: []
        )

        _ = deriver.derive(sample: firstSample)
        let records = deriver.derive(sample: quietSample)
        let record = try requireRecord(pid: 7, in: records)

        try expectFalse(record.isCurrentSample)
        try expectEqual(record.downloadBytesPerSecond, 0)
        try expectEqual(record.oneMinuteDownloadBytes, 512 * 1024)
        try expectEqual(record.remoteHostsTop, [])
    }

    private static func testTags() throws {
        let deriver = ProcessTrafficActivityDeriver()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_200)

        for offset in 0..<4 {
            let records = deriver.derive(
                sample: ProcessTrafficSample(
                    sampleTime: baseDate.addingTimeInterval(TimeInterval(offset)),
                    processes: [
                        ProcessTrafficSampleInput(
                            pid: 99,
                            processName: "Sync Agent",
                            bundleIdentifier: "com.example.sync",
                            isForegroundApp: false,
                            downloadBytesPerSecond: 256 * 1024,
                            uploadBytesPerSecond: 256 * 1024,
                            activeConnectionCount: 4,
                            remoteHostsTop: ["api.example.com"],
                            failureCountDelta: 0
                        )
                    ]
                )
            )
            try expectFalse(try requireRecord(pid: 99, in: records).tags.contains(.burst))
        }

        let burstRecords = deriver.derive(
            sample: ProcessTrafficSample(
                sampleTime: baseDate.addingTimeInterval(4),
                processes: [
                    ProcessTrafficSampleInput(
                        pid: 99,
                        processName: "Sync Agent",
                        bundleIdentifier: "com.example.sync",
                        isForegroundApp: false,
                        downloadBytesPerSecond: 6 * 1024 * 1024,
                        uploadBytesPerSecond: 2 * 1024 * 1024,
                        activeConnectionCount: 9,
                        remoteHostsTop: ["api.example.com", "upload.example.com"],
                        failureCountDelta: 2
                    )
                ]
            )
        )
        let burstRecord = try requireRecord(pid: 99, in: burstRecords)

        try expectTrue(burstRecord.tags.contains(.burst))
        try expectTrue(burstRecord.tags.contains(.retryLike))
        try expectTrue(burstRecord.tags.contains(.highDownload))
        try expectTrue(burstRecord.tags.contains(.highUpload))
        try expectTrue(burstRecord.tags.contains(.backgroundActive))
    }

    private static func requireRecord(
        pid: Int32,
        in records: [ProcessTrafficProcessRecord]
    ) throws -> ProcessTrafficProcessRecord {
        guard let record = records.first(where: { $0.pid == pid }) else {
            throw TestFailure(message: "Missing record for pid \(pid)")
        }

        return record
    }

    private static func expectTrue(_ condition: Bool) throws {
        guard condition else {
            throw TestFailure(message: "Expected condition to be true")
        }
    }

    private static func expectFalse(_ condition: Bool) throws {
        guard !condition else {
            throw TestFailure(message: "Expected condition to be false")
        }
    }

    private static func expectEqual<T: Equatable>(
        _ lhs: T,
        _ rhs: T
    ) throws {
        guard lhs == rhs else {
            throw TestFailure(message: "Expected \(lhs) == \(rhs)")
        }
    }
}
