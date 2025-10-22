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
    
    var body: some View {
        VStack(spacing: 0) {
            // ✨ P1: 回复预览条
            if let replyTo = client.replyManager.replyingTo {
                ReplyPreviewBar(
                    replyTo: replyTo,
                    onCancel: {
                        client.replyManager.clearReply()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 分隔线
            Divider()
                .background(HChatTheme.separator)
            
            // 输入区域
            HStack(alignment: .bottom, spacing: HChatTheme.mediumSpacing) {
                // 附件按钮
                Button {
                    onAttachment()
                    HapticManager.impact(style: .light)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(HChatTheme.accent)
                }
                .buttonStyle(.plain)
                
                // 输入框
                HStack(alignment: .bottom, spacing: HChatTheme.smallSpacing) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .lineLimit(1...6)
                .font(HChatTheme.bodyFont)
                .focused($isInputFocused)
                .onSubmit {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }
                }
                .padding(.horizontal, HChatTheme.mediumSpacing)
                .padding(.vertical, HChatTheme.smallSpacing)
                .background(
                    RoundedRectangle(cornerRadius: HChatTheme.largeCornerRadius, style: .continuous)
                        .fill(HChatTheme.tertiaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HChatTheme.largeCornerRadius, style: .continuous)
                        .stroke(isInputFocused ? HChatTheme.accent.opacity(0.3) : HChatTheme.border, lineWidth: 1.5)
                )
                
                // 发送按钮
                Button {
                    onSend()
                    HapticManager.impact(style: .medium)
                } label: {
                    Image(systemName: inputText.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            inputText.isEmpty ? HChatTheme.tertiaryText : HChatTheme.accent
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
                .animation(HChatTheme.quickAnimation, value: inputText.isEmpty)
            }
            .padding(.horizontal, HChatTheme.largeSpacing)
            .padding(.vertical, HChatTheme.mediumSpacing)
            .background(HChatTheme.background)
        }
        .animation(HChatTheme.standardAnimation, value: client.replyManager.replyingTo != nil)
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

