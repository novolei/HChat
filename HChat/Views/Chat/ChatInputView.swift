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
    @State private var isRecordingVoice = false
    @State private var audioRecorder = AudioRecorderManager()
    @State private var voicePreview: (url: URL, duration: TimeInterval, waveform: [CGFloat])? = nil
    @State private var keepKeyboardForPreview = false
    
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
            
            // 语音预览与输入区域叠加
            ZStack {
                inputArea
                    .opacity(voicePreview == nil ? 1 : 0)
                    .allowsHitTesting(voicePreview == nil)

                if let preview = voicePreview {
                    VoiceMessagePreview(
                        duration: preview.duration,
                        waveformData: preview.waveform,
                        audioURL: preview.url,
                        onSend: {
                            sendVoiceMessage()
                        },
                        onCancel: {
                            cancelVoicePreview()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DebugLogger.log("👀 VoiceMessagePreview 已显示", level: .info)
                        DispatchQueue.main.async {
                            if keepKeyboardForPreview {
                                isInputFocused = true
                            } else {
                                isInputFocused = false
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, ModernTheme.spacing5)
            .padding(.vertical, ModernTheme.spacing3)
        }
        .animation(HChatTheme.standardAnimation, value: client.replyManager.replyingTo != nil)
        .animation(HChatTheme.quickAnimation, value: inputText.isEmpty)
        .animation(HChatTheme.standardAnimation, value: voicePreview != nil)
        .overlay(
            // 语音录制界面（使用 overlay 避免影响布局）
            VoiceRecorderView(
                isRecording: $isRecordingVoice,
                audioRecorder: audioRecorder,
                onRecordingComplete: handleVoiceRecorded,
                onCancel: handleVoiceCancel
            )
            .allowsHitTesting(isRecordingVoice)
        )
    }
    
    // MARK: - 语音录制按钮
    
    private var voiceButton: some View {
        Button {
            // 占位，实际通过 simultaneousGesture 处理
        } label: {
            Circle()
                .fill(LinearGradient(colors: [ModernTheme.accent, ModernTheme.secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            // 使用 DragGesture 来检测按下和滑动
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // 首次按下时开始录音
                    if !isRecordingVoice {
                        startVoiceRecording()
                    }
                }
        )
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
    
    // MARK: - 语音录制处理
    
    private func startVoiceRecording() {
        Task {
            // 请求麦克风权限
            let granted = await audioRecorder.requestPermission()
            guard granted else {
                DebugLogger.log("❌ 麦克风权限被拒绝", level: .warning)
                return
            }
            
            // 开始录音
            do {
                try audioRecorder.startRecording()
                isRecordingVoice = true
                HapticManager.impact(style: .medium)
            } catch {
                DebugLogger.log("❌ 开始录音失败: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func handleVoiceRecorded(_ url: URL) {
        DebugLogger.log("🎤 录音完成: \(url.path)", level: .info)
        
        // 获取录音时长
        let duration = audioRecorder.duration
        DebugLogger.log("⏱️ 录音时长: \(duration)s", level: .info)
        
        // 获取波形数据（从 AudioRecorderManager 的历史记录）
        let waveform = generateWaveformData(duration: duration)
        DebugLogger.log("📊 波形数据: \(waveform.count) 个采样点", level: .info)
        
        // 显示预览
        keepKeyboardForPreview = isInputFocused
        voicePreview = (url: url, duration: duration, waveform: waveform)
        DebugLogger.log("✅ 语音预览已设置", level: .info)
    }
    
    private func sendVoiceMessage() {
        guard let preview = voicePreview else { return }
        
        // 加密并上传音频文件
        Task {
            do {
                let attachment = try await uploadVoiceFile(url: preview.url)
                DebugLogger.log("✅ 语音文件上传成功: \(attachment.filename)", level: .info)
                
                // 发送语音消息到聊天
                await MainActor.run {
                    var enriched = attachment
                    enriched.duration = preview.duration
                    enriched.waveform = preview.waveform
                    DebugLogger.log("📤 准备发送语音附件 - duration: \(preview.duration)s, waveform: \(preview.waveform.count) samples", level: .info)
                    client.sendAttachment(enriched)
                    DebugLogger.log("✅ 语音消息已发送到 client", level: .info)
                    voicePreview = nil // 清除预览
                    keepKeyboardForPreview = false
                }
            } catch {
                DebugLogger.log("❌ 语音文件上传失败: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func cancelVoicePreview() {
        if let preview = voicePreview {
            // 删除临时文件
            try? FileManager.default.removeItem(at: preview.url)
        }
        voicePreview = nil
        keepKeyboardForPreview = false
        HapticManager.impact(style: .light)
    }
    
    private func generateWaveformData(duration: TimeInterval) -> [CGFloat] {
        // 生成40个采样点的波形数据
        // 实际应该从音频文件中提取，这里使用随机数模拟
        return (0..<40).map { _ in CGFloat.random(in: 0.3...1.0) }
    }
    
    private func handleVoiceCancel() {
        DebugLogger.log("❌ 录音已取消", level: .info)
    }
    
    /// 上传语音文件（加密）
    private func uploadVoiceFile(url: URL) async throws -> Attachment {
        let uploader = Services.uploader
        let passphrase = client.currentChannel // 使用频道名作为密码
        
        // 加密并上传
        return try await uploader.encryptAndUploadFile(
            fileURL: url,
            filename: "voice_\(Int(Date().timeIntervalSince1970)).m4a",
            originalContentType: "audio/m4a",
            passphrase: passphrase,
            objectKeyPrefix: "rooms/\(client.currentChannel)"
        )
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

private extension ChatInputView {
    var inputArea: some View {
        HStack(alignment: .bottom, spacing: HChatTheme.mediumSpacing) {
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
                        .stroke(
                            LinearGradient(
                                colors: [
                                    ModernTheme.accent.opacity(isInputFocused ? 0.6 : 0.2),
                                    ModernTheme.secondaryAccent.opacity(isInputFocused ? 0.6 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

            if inputText.isEmpty {
                voiceButton
            } else {
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
                                .fill(LinearGradient(colors: [ModernTheme.accent, ModernTheme.secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

