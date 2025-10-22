//
//  TypingIndicatorView.swift
//  HChat
//
//  Created on 2025-10-22.
//  正在输入指示器 UI 组件

import SwiftUI

/// 正在输入指示器视图
struct TypingIndicatorView: View {
    let typingUsers: [String]
    
    var body: some View {
        if !typingUsers.isEmpty {
            HStack(spacing: 8) {
                // 动画的三个点
                TypingDotsAnimation()
                
                // 提示文本
                Text(typingText)
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.secondaryText)
            }
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.vertical, ModernTheme.spacing2)
            .background(
                RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous)
                    .fill(Color(.systemGray6).opacity(0.8))
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
    
    private var typingText: String {
        switch typingUsers.count {
        case 1:
            return "\(typingUsers[0]) 正在输入..."
        case 2:
            return "\(typingUsers[0]) 和 \(typingUsers[1]) 正在输入..."
        case 3:
            return "\(typingUsers[0])、\(typingUsers[1]) 和 \(typingUsers[2]) 正在输入..."
        default:
            return "多人正在输入..."
        }
    }
}

/// 三个点的动画
struct TypingDotsAnimation: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(ModernTheme.accent)
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 0.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - 预览

#Preview("单人输入") {
    VStack {
        TypingIndicatorView(typingUsers: ["Alice"])
        Spacer()
    }
    .padding()
}

#Preview("多人输入") {
    VStack(spacing: 16) {
        TypingIndicatorView(typingUsers: ["Alice", "Bob"])
        TypingIndicatorView(typingUsers: ["Alice", "Bob", "Charlie"])
        TypingIndicatorView(typingUsers: ["Alice", "Bob", "Charlie", "David"])
        Spacer()
    }
    .padding()
}

#Preview("动画演示") {
    VStack {
        TypingDotsAnimation()
        Spacer()
    }
    .padding()
}

