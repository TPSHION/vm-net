//
//  RegionScreenshotController.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit
import Carbon.HIToolbox
import ScreenCaptureKit

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
        let session = RegionCaptureOverlaySession(
            screens: NSScreen.screens,
            onComplete: { [weak self] selection in
                guard let self else { return }
                self.selectionSession = nil
                Task {
                    await self.captureSelection(selection)
                }
            },
            onCancel: { [weak self] in
                self?.selectionSession = nil
            }
        )

        selectionSession = session
        NSApp.activate(ignoringOtherApps: true)
        session.begin()
    }

    private func captureSelection(_ selection: RegionSelection) async {
        do {
            await Task.yield()
            let image = try await captureImage(for: selection)
            let url = try saveImage(image)
            copyImageToPasteboard(image)
            lastCaptureURL = url
            needsPermission = false
            showStatus(
                L10n.tr("screenshot.status.saved", url.lastPathComponent),
                kind: .success
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

    private func saveImage(_ image: CGImage) throws -> URL {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw RegionScreenshotError.saveFailed
        }

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
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw RegionScreenshotError.saveFailed
        }
    }

    private func copyImageToPasteboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        pasteboard.writeObjects([nsImage])
    }

    private func captureImage(
        for selection: RegionSelection
    ) async throws -> CGImage {
        guard #available(macOS 14.0, *) else {
            throw RegionScreenshotError.unsupported
        }

        if #available(macOS 15.2, *) {
            return try await SCScreenshotManager.captureImage(in: selection.rect)
        }

        let shareableContent = try await loadShareableContent()
        let activeScreen = screenContainingPoint(selection.rect.origin)
            ?? selection.originScreen
        guard
            let displayID = activeScreen.cgDisplayID,
            let display = shareableContent.displays.first(where: {
                $0.displayID == displayID
            })
        else {
            throw RegionScreenshotError.displayUnavailable
        }

        let excludedApplications = shareableContent.applications.filter {
            $0.processID == NSRunningApplication.current.processIdentifier
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
            selection.rect,
            for: activeScreen
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
    private func loadShareableContent() async throws -> SCShareableContent {
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

    private func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }
    }

    private func adjustRectForScreen(
        _ rect: CGRect,
        for screen: NSScreen
    ) -> CGRect {
        let screenHeight = screen.frame.height + screen.frame.minY
        return CGRect(
            x: rect.origin.x - screen.frame.minX,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
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
