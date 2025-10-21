//
//  Theme.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  ✨ UI优化：现代化主题系统，支持亮色/暗色自适应
//

import SwiftUI

// MARK: - 🎨 现代化主题系统

/// HChat 主题配置
enum HChatTheme {
    // MARK: - 颜色系统
    
    /// 主背景色（自适应亮色/暗色模式）
    static let background = Color(uiColor: .systemBackground)
    
    /// 次级背景色（用于卡片、面板）
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    
    /// 三级背景色（用于分组列表）
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    
    /// 聊天背景（更柔和的背景）
    static let chatBackground = Color(uiColor: .systemGroupedBackground)
    
    // MARK: - 消息气泡
    
    /// 我的消息气泡（蓝色渐变）
    static var myMessageBubble: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.48, blue: 1.0),     // 系统蓝
                Color(red: 0.0, green: 0.40, blue: 0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 我的消息文字颜色
    static let myMessageText = Color.white
    
    /// 他人消息气泡
    static let otherMessageBubble = Color(uiColor: .secondarySystemGroupedBackground)
    
    /// 他人消息文字颜色
    static let otherMessageText = Color(uiColor: .label)
    
    /// 系统消息气泡
    static let systemMessageBubble = Color(uiColor: .tertiarySystemGroupedBackground)
    
    // MARK: - 强调色
    
    /// 主强调色（用于按钮、链接等）
    static let accent = Color.accentColor
    
    /// 次级强调色
    static let secondaryAccent = Color(red: 0.35, green: 0.34, blue: 0.84) // 紫色
    
    /// 成功色
    static let success = Color.green
    
    /// 警告色
    static let warning = Color.orange
    
    /// 错误色
    static let error = Color.red
    
    // MARK: - 文字颜色
    
    /// 主文字
    static let primaryText = Color(uiColor: .label)
    
    /// 次级文字
    static let secondaryText = Color(uiColor: .secondaryLabel)
    
    /// 三级文字
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    
    /// 占位符文字
    static let placeholderText = Color(uiColor: .placeholderText)
    
    // MARK: - 边框和分隔线
    
    /// 分隔线颜色
    static let separator = Color(uiColor: .separator)
    
    /// 边框颜色
    static let border = Color(uiColor: .separator).opacity(0.3)
    
    // MARK: - 阴影
    
    /// 轻阴影
    static let lightShadow = Color.black.opacity(0.05)
    
    /// 中阴影
    static let mediumShadow = Color.black.opacity(0.1)
    
    /// 重阴影
    static let heavyShadow = Color.black.opacity(0.2)
    
    // MARK: - 字体系统
    
    /// 标题字体
    static let titleFont = Font.system(.title2, design: .rounded, weight: .bold)
    
    /// 标题字体（小）
    static let smallTitleFont = Font.system(.title3, design: .rounded, weight: .semibold)
    
    /// 正文字体
    static let bodyFont = Font.system(.body, design: .default)
    
    /// 等宽字体
    static let monospacedFont = Font.system(.body, design: .monospaced)
    
    /// 小字体
    static let captionFont = Font.system(.caption, design: .default)
    
    /// 按钮字体
    static let buttonFont = Font.system(.body, design: .rounded, weight: .semibold)
    
    // MARK: - 圆角
    
    /// 小圆角
    static let smallCornerRadius: CGFloat = 8
    
    /// 中圆角
    static let mediumCornerRadius: CGFloat = 12
    
    /// 大圆角（消息气泡）
    static let largeCornerRadius: CGFloat = 18
    
    /// 超大圆角（胶囊）
    static let extraLargeCornerRadius: CGFloat = 24
    
    // MARK: - 间距
    
    /// 超小间距
    static let tinySpacing: CGFloat = 4
    
    /// 小间距
    static let smallSpacing: CGFloat = 8
    
    /// 中间距
    static let mediumSpacing: CGFloat = 12
    
    /// 大间距
    static let largeSpacing: CGFloat = 16
    
    /// 超大间距
    static let extraLargeSpacing: CGFloat = 24
    
    // MARK: - 动画
    
    /// 快速动画
    static let quickAnimation = Animation.easeOut(duration: 0.15)
    
    /// 标准动画
    static let standardAnimation = Animation.easeInOut(duration: 0.25)
    
    /// 慢动画
    static let slowAnimation = Animation.easeInOut(duration: 0.35)
    
    /// 弹簧动画
    static let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

// MARK: - 兼容性别名（保持向后兼容）

enum HackTheme {
    static let background = HChatTheme.background
    static let panel = HChatTheme.secondaryBackground
    static let panelStroke = HChatTheme.border
    static let myBubble = Color.blue
    static let otherBubble = HChatTheme.otherMessageBubble
    static let systemText = HChatTheme.secondaryText
    static let monospacedBody = HChatTheme.monospacedFont
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
