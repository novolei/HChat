//
//  ModernTheme.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  🎨 现代化设计系统 - 受优秀设计启发的全新主题
//

import SwiftUI

// MARK: - 🎨 现代化主题系统

enum ModernTheme {
    
    // MARK: - 🌈 配色方案（柔和、温暖）
    
    /// 主背景色 - 温暖的米色/灰色
    static let primaryBackground = Color(hex: "F5F3F0")
    
    /// 次级背景 - 更浅的米色
    static let secondaryBackground = Color(hex: "FDFCFA")
    
    /// 卡片背景 - 纯白
    static let cardBackground = Color.white
    
    /// 深色背景（用于暗模式或特殊区域）
    static let darkBackground = Color(hex: "2C2C2E")
    
    // MARK: - 💬 消息气泡颜色
    
    /// 我的消息 - 柔和的蓝色渐变
    static var myMessageGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "6B9BD1"),  // 柔和蓝
                Color(hex: "5A8BC4")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 他人消息 - 浅灰色
    static let otherMessageBackground = Color(hex: "E8E6E3")
    
    /// 系统消息 - 极浅灰
    static let systemMessageBackground = Color(hex: "F0EFEC")
    
    // MARK: - 🎯 强调色和状态色
    
    /// 主强调色 - 柔和的蓝色
    static let accent = Color(hex: "6B9BD1")
    
    /// 次级强调色 - 柔和的紫色
    static let secondaryAccent = Color(hex: "9B8CD1")
    
    /// 成功/Essential - 柔和的绿色
    static let success = Color(hex: "7FB069")
    
    /// 警告/Urgent - 柔和的橙色
    static let warning = Color(hex: "E09F3E")
    
    /// 错误/Critical - 柔和的红色
    static let error = Color(hex: "D66853")
    
    /// Blocking - 深绿色
    static let blocking = Color(hex: "5F8D4E")
    
    // MARK: - 📝 文字颜色
    
    /// 主文字 - 深灰
    static let primaryText = Color(hex: "2C2C2E")
    
    /// 次级文字 - 中灰
    static let secondaryText = Color(hex: "6C6C70")
    
    /// 三级文字 - 浅灰
    static let tertiaryText = Color(hex: "AEAEB2")
    
    /// 占位符文字
    static let placeholderText = Color(hex: "C7C7CC")
    
    /// 反色文字（在深色背景上）
    static let inverseText = Color.white
    
    // MARK: - 🔲 边框和分隔线
    
    /// 边框颜色
    static let border = Color(hex: "E5E5EA").opacity(0.5)
    
    /// 分隔线
    static let separator = Color(hex: "D1D1D6").opacity(0.3)
    
    // MARK: - 🌫️ 阴影（柔和、自然）
    
    /// 卡片阴影
    static let cardShadow = Color.black.opacity(0.08)
    
    /// 悬浮阴影（hover）
    static let hoverShadow = Color.black.opacity(0.12)
    
    /// 深阴影
    static let deepShadow = Color.black.opacity(0.15)
    
    // MARK: - 🎨 渐变色
    
    /// 背景渐变（可选）
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "FDFCFA"),
                Color(hex: "F5F3F0")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// 卡片渐变
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color(hex: "FDFCFA")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - 🔠 字体系统
    
    /// 大标题
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    
    /// 标题1
    static let title1 = Font.system(.title, design: .rounded, weight: .bold)
    
    /// 标题2
    static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    
    /// 标题3
    static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
    
    /// 正文
    static let body = Font.system(.body, design: .default)
    
    /// 正文（粗体）
    static let bodyBold = Font.system(.body, design: .default, weight: .semibold)
    
    /// 小标题
    static let callout = Font.system(.callout, design: .default)
    
    /// 次要文字
    static let subheadline = Font.system(.subheadline, design: .default)
    
    /// 脚注
    static let footnote = Font.system(.footnote, design: .default)
    
    /// 说明文字
    static let caption = Font.system(.caption, design: .default)
    
    /// 等宽字体
    static let monospaced = Font.system(.body, design: .monospaced)
    
    // MARK: - 📐 圆角系统
    
    /// 超小圆角
    static let tinyRadius: CGFloat = 6
    
    /// 小圆角
    static let smallRadius: CGFloat = 10
    
    /// 中圆角
    static let mediumRadius: CGFloat = 16
    
    /// 大圆角（卡片）
    static let largeRadius: CGFloat = 20
    
    /// 超大圆角
    static let extraLargeRadius: CGFloat = 28
    
    /// 消息气泡圆角
    static let bubbleRadius: CGFloat = 20
    
    // MARK: - 📏 间距系统
    
    /// 超小间距
    static let spacing1: CGFloat = 4
    
    /// 小间距
    static let spacing2: CGFloat = 8
    
    /// 中小间距
    static let spacing3: CGFloat = 12
    
    /// 中间距
    static let spacing4: CGFloat = 16
    
    /// 大间距
    static let spacing5: CGFloat = 20
    
    /// 超大间距
    static let spacing6: CGFloat = 24
    
    /// 特大间距
    static let spacing7: CGFloat = 32
    
    // MARK: - 🎭 动画系统
    
    /// 快速动画
    static let quickAnimation = Animation.easeOut(duration: 0.15)
    
    /// 标准动画
    static let standardAnimation = Animation.easeInOut(duration: 0.25)
    
    /// 慢动画
    static let slowAnimation = Animation.easeInOut(duration: 0.35)
    
    /// 弹簧动画（轻）
    static let lightSpring = Animation.spring(response: 0.25, dampingFraction: 0.7)
    
    /// 弹簧动画（标准）
    static let standardSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)
    
    /// 弹簧动画（重）
    static let heavySpring = Animation.spring(response: 0.45, dampingFraction: 0.65)
    
    // MARK: - 🎨 标签颜色
    
    struct TagColors {
        static let essential = Color(hex: "7FB069")
        static let urgent = Color(hex: "E09F3E")
        static let blocking = Color(hex: "5F8D4E")
        static let normal = Color(hex: "AEAEB2")
    }
    
    // MARK: - 📊 优先级颜色
    
    struct PriorityColors {
        static let high = Color(hex: "E09F3E")
        static let medium = Color(hex: "6B9BD1")
        static let low = Color(hex: "AEAEB2")
    }
}

// MARK: - 🛠️ 辅助扩展

extension Color {
    /// 从十六进制字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 🎴 现代化卡片修饰符

struct ModernCardModifier: ViewModifier {
    var padding: CGFloat = ModernTheme.spacing4
    var backgroundColor: Color = ModernTheme.cardBackground
    var shadowRadius: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
            .shadow(color: ModernTheme.cardShadow, radius: shadowRadius, x: 0, y: 4)
    }
}

extension View {
    /// 应用现代化卡片样式
    func modernCard(
        padding: CGFloat = ModernTheme.spacing4,
        backgroundColor: Color = ModernTheme.cardBackground,
        shadowRadius: CGFloat = 10
    ) -> some View {
        self.modifier(ModernCardModifier(
            padding: padding,
            backgroundColor: backgroundColor,
            shadowRadius: shadowRadius
        ))
    }
}

// MARK: - 🏷️ 标签样式

struct ModernTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(ModernTheme.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

