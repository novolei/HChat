//
//  ChatInputView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  ✨ UI优化：现代化聊天输入框，优雅的设计和流畅的交互
//

import SwiftUI

struct ChatInputView: View {
    var client: HackChatClient
    @Binding var inputText: String
    var onSend: () -> Void
    var onAttachment: () -> Void
    
    @FocusState private var isInputFocused: Bool
    @State private var lastTypingTime: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            // ✨ P1: 回复预览条（优化：移除复杂过渡动画）
            if let replyTo = client.replyManager.replyingTo {
                ReplyPreviewBar(
                    replyTo: replyTo,
                    onCancel: {
                        client.replyManager.clearReply()
                    }
                )
                .transition(.opacity)
            }
            
            // 输入区域
            HStack(alignment: .bottom, spacing: HChatTheme.mediumSpacing) {
                // 附件按钮
                Button {
                    onAttachment()
                    HapticManager.impact(style: .light)
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [ModernTheme.accent, ModernTheme.secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                }
                .buttonStyle(.plain)
                
                // 输入框
                TextField("输入消息...", text: $inputText, axis: .vertical)
                    .lineLimit(1...6)
                    .font(HChatTheme.bodyFont)
                    .focused($isInputFocused)
                    .onChange(of: inputText) { _, newValue in
                        handleTypingChange(newValue)
                    }
                    .onSubmit {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }
                    .padding(.horizontal, HChatTheme.mediumSpacing)
                    .padding(.vertical, HChatTheme.mediumSpacing)
                    .background(
                        RoundedRectangle(cornerRadius: ModernTheme.extraLargeRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernTheme.extraLargeRadius, style: .continuous)
                            .stroke(LinearGradient(colors: [ModernTheme.accent.opacity(isInputFocused ? 0.6 : 0.2), ModernTheme.secondaryAccent.opacity(isInputFocused ? 0.6 : 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                    )
                
                // 发送按钮
                Button {
                    onSend()
                    HapticManager.impact(style: .medium)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: inputText.isEmpty ? [ModernTheme.tertiaryText.opacity(0.4), ModernTheme.tertiaryText.opacity(0.2)] : [ModernTheme.accent, ModernTheme.secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
                .animation(HChatTheme.quickAnimation, value: inputText.isEmpty)
            }
            .padding(.horizontal, ModernTheme.spacing5)
            .padding(.vertical, ModernTheme.spacing3)
        }
        .animation(HChatTheme.standardAnimation, value: client.replyManager.replyingTo != nil)
    }
    
    // MARK: - 正在输入处理
    
    /// 处理输入变化，发送正在输入事件（节流：每 2 秒最多发送一次）
    private func handleTypingChange(_ text: String) {
        // 如果文本为空，重置 lastTypingTime（用户发送消息或清空输入框）
        guard !text.isEmpty else {
            lastTypingTime = nil
            return
        }
        
        let now = Date()
        
        // 如果距离上次发送不到 2 秒，不发送
        if let lastTime = lastTypingTime, now.timeIntervalSince(lastTime) < 2.0 {
            return
        }
        
        // 发送正在输入事件
        client.typingIndicatorManager.sendTypingStatus(channel: client.currentChannel)
        lastTypingTime = now
    }
}

// MARK: - 🎯 触觉反馈管理器

enum HapticManager {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

