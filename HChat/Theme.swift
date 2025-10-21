//
//  Theme.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import SwiftUI

enum HackTheme {
    static let background = Color(hue: 0.62, saturation: 0.05, brightness: 0.08)
    static let panel = Color(hue: 0.62, saturation: 0.10, brightness: 0.13)
    static let panelStroke = Color.white.opacity(0.06)
    static let myBubble = Color.accentColor.opacity(0.18)
    static let otherBubble = Color.white.opacity(0.06)
    static let systemText = Color.secondary
    static let monospacedBody = Font.system(.body, design: .monospaced)
}

extension String {
    var hcBaseNick: String { self.split(separator: "#").first.map(String.init) ?? self }
}

func colorForNickname(_ nick: String) -> Color {
    let h = Double(abs(nick.hcBaseNick.hashValue % 360)) / 360.0
    return Color(hue: h, saturation: 0.55, brightness: 0.85)
}

func ymdPathString(_ date: Date = Date()) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d/%02d/%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
}

enum TimestampStyle: Int, CaseIterable {
    case off = 0, relative, absolute
    var title: String {
        switch self {
        case .off: return "时间戳：关"
        case .relative: return "时间戳：相对"
        case .absolute: return "时间戳：绝对"
        }
    }
}
func formattedTimestamp(_ date: Date, style: TimestampStyle) -> String? {
    switch style {
    case .off: return nil
    case .relative:
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    case .absolute:
        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}

struct CapsuleFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(HackTheme.panel.opacity(0.9), in: Capsule())
            .overlay(Capsule().stroke(HackTheme.panelStroke))
            .foregroundStyle(.primary)
    }
}
