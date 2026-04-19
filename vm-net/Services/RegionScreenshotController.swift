//
//  RegionScreenshotController.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit
import Carbon.HIToolbox
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

@MainActor
final class RegionScreenshotController: ObservableObject {

    enum StatusKind {
        case neutral
        case success
        case error
    }

    @Published private(set) var statusMessage: String?
    @Published private(set) var statusKind: StatusKind = .neutral
    @Published private(set) var needsPermission = false
    @Published private(set) var lastCaptureURL: URL?

    private var selectionSession: RegionCaptureOverlaySession?
    private var previousFrontmostApplication: NSRunningApplication?
    private let previewController = RegionCapturePreviewController()

    var supportsRegionCapture: Bool {
        if #available(macOS 14.0, *) {
            return true
        }

        return false
    }

    func beginCapture() {
        guard selectionSession == nil else { return }

        Task {
            await beginCaptureFlow()
        }
    }

    func openSystemSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            )
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func clearStatus() {
        statusMessage = nil
        statusKind = .neutral
    }

    func showShortcutRegistrationFailed() {
        showStatus(
            L10n.tr("screenshot.status.shortcutRegistrationFailed"),
            kind: .error
        )
    }

    private func beginCaptureFlow() async {
        guard supportsRegionCapture else {
            showStatus(
                L10n.tr("screenshot.status.unsupported"),
                kind: .error
            )
            return
        }

        guard await ensurePermission() else { return }
        startSelection()
    }

    private func ensurePermission() async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            needsPermission = false
            return true
        }

        let granted = await requestScreenCaptureAccess()
        needsPermission = !granted

        showStatus(
            granted
                ? L10n.tr("screenshot.status.permissionRestartRequired")
                : L10n.tr("screenshot.status.permissionDenied"),
            kind: .error
        )

        return false
    }

    private func requestScreenCaptureAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let granted = CGRequestScreenCaptureAccess()
                continuation.resume(returning: granted)
            }
        }
    }

    private func startSelection() {
        captureCurrentFrontmostApplication()

        let session = RegionCaptureOverlaySession(
            screens: NSScreen.screens,
            onCommit: { [weak self] selection, action in
                guard let self else { return }
                self.selectionSession = nil
                self.restorePreviousFrontmostApplication()
                Task {
                    await self.captureSelection(selection, action: action)
                }
            },
            onCancel: { [weak self] in
                self?.selectionSession = nil
                self?.restorePreviousFrontmostApplication()
            }
        )

        selectionSession = session
        NSApp.activate(ignoringOtherApps: true)
        session.begin()
    }

    private func captureSelection(
        _ selection: RegionSelection,
        action: RegionCaptureCommitAction
    ) async {
        let request = captureRequest(for: selection)

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try await RegionScreenshotPipeline.capture(
                    request,
                    action: action
                )
            }.value

            needsPermission = false
            switch action {
            case .copyToClipboard:
                copyImageToPasteboard(result.pngData)
                lastCaptureURL = nil
                showStatus(
                    L10n.tr("screenshot.status.copied"),
                    kind: .success
                )

            case .saveToFile:
                guard let fileURL = result.fileURL else {
                    showStatus(
                        RegionScreenshotError.saveFailed.localizedDescription,
                        kind: .error
                    )
                    return
                }

                lastCaptureURL = fileURL
                showStatus(
                    L10n.tr("screenshot.status.saved", fileURL.lastPathComponent),
                    kind: .success
                )
            }

            previewController.show(
                pngData: result.pngData,
                pixelSize: NSSize(
                    width: result.pixelWidth,
                    height: result.pixelHeight
                ),
                fileURL: result.fileURL,
                on: selection.originScreen
            )
        } catch let error as RegionScreenshotError {
            showStatus(error.localizedDescription, kind: .error)
        } catch {
            showStatus(
                L10n.tr("screenshot.status.failed"),
                kind: .error
            )
        }
    }

    private func showStatus(_ message: String, kind: StatusKind) {
        statusMessage = message
        statusKind = kind
    }

    private func copyImageToPasteboard(_ pngData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
    }

    private func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }
    }

    private func captureRequest(for selection: RegionSelection) -> RegionCaptureRequest {
        let activeScreen = screenContainingPoint(selection.rect.origin)
            ?? selection.originScreen

        return RegionCaptureRequest(
            rect: selection.rect,
            displayID: activeScreen.cgDisplayID,
            screenFrame: activeScreen.frame
        )
    }

    private func captureCurrentFrontmostApplication() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard
            let frontmostApplication = NSWorkspace.shared.frontmostApplication,
            frontmostApplication.processIdentifier != currentPID
        else {
            previousFrontmostApplication = nil
            return
        }

        previousFrontmostApplication = frontmostApplication
    }

    private func restorePreviousFrontmostApplication() {
        guard let previousFrontmostApplication else { return }
        self.previousFrontmostApplication = nil

        guard !previousFrontmostApplication.isTerminated else { return }

        DispatchQueue.main.async {
            previousFrontmostApplication.activate(options: [.activateIgnoringOtherApps])
        }
    }
}

private struct RegionCaptureRequest: Sendable {
    let rect: CGRect
    let displayID: CGDirectDisplayID?
    let screenFrame: CGRect
}

private struct RegionCaptureResult: Sendable {
    let pngData: Data
    let fileURL: URL?
    let pixelWidth: Int
    let pixelHeight: Int
}

private enum RegionScreenshotPipeline {

    static func capture(
        _ request: RegionCaptureRequest,
        action: RegionCaptureCommitAction
    ) async throws -> RegionCaptureResult {
        let image = try await captureImage(for: request)
        let pngData = try pngData(from: image)
        let fileURL: URL?

        switch action {
        case .copyToClipboard:
            fileURL = nil
        case .saveToFile:
            fileURL = try saveImageData(pngData)
        }

        return RegionCaptureResult(
            pngData: pngData,
            fileURL: fileURL,
            pixelWidth: image.width,
            pixelHeight: image.height
        )
    }

    private static func captureImage(
        for request: RegionCaptureRequest
    ) async throws -> CGImage {
        guard #available(macOS 14.0, *) else {
            throw RegionScreenshotError.unsupported
        }

        if #available(macOS 15.2, *) {
            return try await SCScreenshotManager.captureImage(in: request.rect)
        }

        let shareableContent = try await loadShareableContent()
        guard
            let displayID = request.displayID,
            let display = shareableContent.displays.first(where: {
                $0.displayID == displayID
            })
        else {
            throw RegionScreenshotError.displayUnavailable
        }

        let excludedApplications = shareableContent.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )

        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }

        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.scalesToFit = false
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.sourceRect = adjustRectForScreen(
            request.rect,
            screenFrame: request.screenFrame
        )
        configuration.width = max(
            1,
            Int(configuration.sourceRect.width * CGFloat(filter.pointPixelScale))
        )
        configuration.height = max(
            1,
            Int(configuration.sourceRect.height * CGFloat(filter.pointPixelScale))
        )

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    @available(macOS 14.0, *)
    private static func loadShareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            ) { shareableContent, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let shareableContent else {
                    continuation.resume(
                        throwing: RegionScreenshotError.displayUnavailable
                    )
                    return
                }

                continuation.resume(returning: shareableContent)
            }
        }
    }

    private static func adjustRectForScreen(
        _ rect: CGRect,
        screenFrame: CGRect
    ) -> CGRect {
        let screenHeight = screenFrame.height + screenFrame.minY
        return CGRect(
            x: rect.origin.x - screenFrame.minX,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private static func pngData(from image: CGImage) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw RegionScreenshotError.saveFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RegionScreenshotError.saveFailed
        }

        return mutableData as Data
    }

    private static func saveImageData(_ pngData: Data) throws -> URL {
        let directory = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "vm-net-\(formatter.string(from: Date())).png"
        let screenshotsDirectory = directory.appendingPathComponent(
            "vm-net",
            isDirectory: true
        )

        do {
            try FileManager.default.createDirectory(
                at: screenshotsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            throw RegionScreenshotError.saveFailed
        }

        let url = screenshotsDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            throw RegionScreenshotError.saveFailed
        }
    }
}

struct RegionSelection {
    let rect: CGRect
    let originScreen: NSScreen
}

private enum RegionScreenshotError: LocalizedError {
    case unsupported
    case displayUnavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return L10n.tr("screenshot.status.unsupported")
        case .displayUnavailable:
            return L10n.tr("screenshot.status.displayUnavailable")
        case .saveFailed:
            return L10n.tr("screenshot.status.saveFailed")
        }
    }
}
