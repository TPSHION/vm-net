//
//  DesktopPetAccessFormatter.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation

enum DesktopPetAccessFormatter {

    static func expirationString(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .omitted
            )
            .locale(L10n.locale)
        )
    }
}
