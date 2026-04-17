//
//  Localization.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation

enum L10n {

    private static let tableName = "Localizable"
    private static let lock = NSLock()
    private static var language: AppLanguage = .system

    static var locale: Locale {
        currentLanguage.locale
    }

    static func setLanguage(_ language: AppLanguage) {
        lock.lock()
        self.language = language
        lock.unlock()
    }

    static func tr(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: tableName)
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = tr(key)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private static var currentLanguage: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return language
    }

    private static var localizedBundle: Bundle {
        guard
            let identifier = currentLanguage.localizationIdentifier,
            let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return Bundle.main
        }

        return bundle
    }
}
