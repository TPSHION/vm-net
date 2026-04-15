//
//  NSScreen+DisplayIdentifier.swift
//  vm-net
//
//  Created by Codex on 2026/4/15.
//

import AppKit

extension NSScreen {

    var displayIdentifier: String? {
        guard
            let screenNumber = deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber
        else {
            return nil
        }

        return screenNumber.stringValue
    }
}
