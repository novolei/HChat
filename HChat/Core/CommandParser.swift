//
//  CommandParser.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation

enum CommandParser {
    static func parse(_ raw: String) -> ClientCommand? {
        guard raw.hasPrefix("/") else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let cmd = parts.first!.lowercased()
        let arg = parts.count > 1 ? String(parts[1]) : ""

        switch cmd {
        case "/join": return arg.isEmpty ? .unknown(trimmed) : .join(arg)
        case "/nick": return arg.isEmpty ? .unknown(trimmed) : .nick(arg)
        case "/me":   return arg.isEmpty ? .unknown(trimmed) : .me(arg)
        case "/clear": return .clear
        case "/help":  return .help
        case "/dm":
            let comps = arg.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if comps.count == 2 { return .dm(String(comps[0]), String(comps[1])) }
            else { return .unknown(trimmed) }
        default:       return .unknown(trimmed)
        }
    }

    /// 从 "Waytoon#secret" 自动抽出群口令
    static func extractPassphrase(fromNick nick: String) -> String? {
        // 规则：取 `#` 之后的所有字符，去首尾空格
        guard let idx = nick.firstIndex(of: "#") else { return nil }
        let after = nick[nick.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return after.isEmpty ? nil : after
    }
}
