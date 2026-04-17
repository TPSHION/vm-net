//
//  AppStoreUpdateStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import AppKit
import Foundation

enum AppStoreUpdateMessageKind: Equatable {
    case neutral
    case success
    case error
}

@MainActor
final class AppStoreUpdateStore: ObservableObject {

    private struct LookupResponse: Decodable {
        let resultCount: Int
        let results: [LookupItem]
    }

    private struct LookupItem: Decodable {
        let version: String
        let trackId: Int64?
        let trackViewUrl: URL?
    }

    private let session: URLSession
    private let workspace: NSWorkspace
    private let bundle: Bundle

    @Published private(set) var isChecking = false
    @Published private(set) var message: String?
    @Published private(set) var messageKind: AppStoreUpdateMessageKind = .neutral

    init(
        session: URLSession = .shared,
        workspace: NSWorkspace = .shared,
        bundle: Bundle = .main
    ) {
        self.session = session
        self.workspace = workspace
        self.bundle = bundle
    }

    func checkForUpdates() async {
        guard !isChecking else { return }

        guard
            let bundleIdentifier = bundle.bundleIdentifier,
            let currentVersion = bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String
        else {
            setMessage(L10n.tr("settings.header.update.failed"), kind: .error)
            return
        }

        isChecking = true
        defer { isChecking = false }

        do {
            var components = URLComponents(string: "https://itunes.apple.com/lookup")
            components?.queryItems = [
                URLQueryItem(name: "bundleId", value: bundleIdentifier),
            ]

            guard let url = components?.url else {
                setMessage(L10n.tr("settings.header.update.failed"), kind: .error)
                return
            }

            let (data, response) = try await session.data(from: url)
            guard
                let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode
            else {
                setMessage(L10n.tr("settings.header.update.failed"), kind: .error)
                return
            }

            let lookupResponse = try JSONDecoder().decode(
                LookupResponse.self,
                from: data
            )
            guard
                lookupResponse.resultCount > 0,
                let item = lookupResponse.results.first
            else {
                setMessage(
                    L10n.tr("settings.header.update.unavailable"),
                    kind: .neutral
                )
                return
            }

            if item.version.compare(currentVersion, options: .numeric) == .orderedDescending {
                let targetURL = appStoreURL(for: item)
                guard workspace.open(targetURL) else {
                    setMessage(L10n.tr("settings.header.update.failed"), kind: .error)
                    return
                }

                setMessage(
                    L10n.tr("settings.header.update.available", item.version),
                    kind: .neutral
                )
                return
            }

            setMessage(
                L10n.tr("settings.header.update.current", currentVersion),
                kind: .success
            )
        } catch {
            setMessage(L10n.tr("settings.header.update.failed"), kind: .error)
        }
    }

    private func appStoreURL(for item: LookupItem) -> URL {
        if
            let trackViewURL = item.trackViewUrl,
            var components = URLComponents(
                url: trackViewURL,
                resolvingAgainstBaseURL: false
            )
        {
            components.scheme = "macappstore"
            if let url = components.url {
                return url
            }
            return trackViewURL
        }

        if let trackId = item.trackId,
           let url = URL(string: "macappstore://itunes.apple.com/app/id\(trackId)") {
            return url
        }

        return URL(string: "macappstore://itunes.apple.com/search?mt=12")!
    }

    private func setMessage(
        _ message: String,
        kind: AppStoreUpdateMessageKind
    ) {
        self.message = message
        self.messageKind = kind
    }
}
