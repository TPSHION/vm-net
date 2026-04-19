//
//  KeyboardShortcut.swift
//  vm-net
//
//  Created by Codex on 2026/4/19.
//

import AppKit
import Carbon.HIToolbox

struct KeyboardShortcut: Equatable {

    static let modifierMask: NSEvent.ModifierFlags = [
        .command,
        .option,
        .control,
        .shift,
    ]

    static let defaultRegionScreenshot = KeyboardShortcut(
        keyCode: UInt16(kVK_ANSI_S),
        modifiers: [.control, .option, .command]
    )

    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    init(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.modifierMask)
    }

    var isValid: Bool {
        !modifiers.isEmpty && !Self.isModifierOnlyKeyCode(keyCode)
    }

    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0

        if modifiers.contains(.command) {
            flags |= UInt32(cmdKey)
        }

        if modifiers.contains(.option) {
            flags |= UInt32(optionKey)
        }

        if modifiers.contains(.control) {
            flags |= UInt32(controlKey)
        }

        if modifiers.contains(.shift) {
            flags |= UInt32(shiftKey)
        }

        return flags
    }

    var displayString: String {
        modifierDisplayString + Self.keyDisplayString(for: keyCode)
    }

    var keyEquivalent: String {
        Self.keyEquivalentString(for: keyCode) ?? ""
    }

    var menuModifierFlags: NSEvent.ModifierFlags {
        modifiers.intersection(Self.modifierMask)
    }

    static func isModifierOnlyKeyCode(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Command,
            kVK_RightCommand,
            kVK_Shift,
            kVK_RightShift,
            kVK_Option,
            kVK_RightOption,
            kVK_Control,
            kVK_RightControl,
            kVK_Function,
            kVK_CapsLock:
            return true
        default:
            return false
        }
    }

    static func keyDisplayString(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Space:
            return "Space"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Fn+Delete"
        case kVK_Escape:
            return "Esc"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_DownArrow:
            return "↓"
        case kVK_UpArrow:
            return "↑"
        case kVK_Home:
            return "Home"
        case kVK_End:
            return "End"
        case kVK_PageUp:
            return "Page Up"
        case kVK_PageDown:
            return "Page Down"
        case kVK_Help:
            return "Help"
        default:
            return keyEquivalentString(for: keyCode)?.uppercased()
                ?? "Key \(keyCode)"
        }
    }

    private var modifierDisplayString: String {
        var result = ""

        if modifiers.contains(.control) {
            result += "⌃"
        }

        if modifiers.contains(.option) {
            result += "⌥"
        }

        if modifiers.contains(.shift) {
            result += "⇧"
        }

        if modifiers.contains(.command) {
            result += "⌘"
        }

        return result
    }

    private static func keyEquivalentString(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return nil
        }
    }
}
