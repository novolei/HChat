//
//  VoiceRecorderView.swift
//  HChat
//
//  Created on 2025-10-22.
//  语音消息录制 UI 组件

import SwiftUI
import AVFoundation

/// 录音状态
enum RecordingState {
    case idle           // 空闲
    case recording      // 录音中
    case willCancel     // 即将取消（手指滑出）
}

/// 语音录制视图
struct VoiceRecorderView: View {
    @Binding var isRecording: Bool
    var audioRecorder: AudioRecorderManager
    var onRecordingComplete: (URL) -> Void
    var onCancel: () -> Void
    
    @State private var recordingState: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 30)
    @State private var timer: Timer?
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 半透明遮罩
            if isRecording {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // 录音提示面板（居中显示）
            if isRecording {
                VStack {
                    Spacer()
                    
                    recordingPanel
                        .offset(y: dragOffset)
                    
                    Spacer()
                        .frame(height: 200) // 为底部输入区域留空间
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isRecording)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: recordingState)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.75), value: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChange(value)
                }
                .onEnded { value in
                    handleDragEnd(value)
                }
        )
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                // 开始录音时启动监控
                startMonitoring()
            } else {
                // 停止录音时清理定时器
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    // MARK: - 录音控制面板
    
    private var recordingPanel: some View {
        VStack(spacing: ModernTheme.spacing5) {
            // 取消提示（滑动时显示）
            if recordingState == .willCancel {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                    Text("松手取消发送")
                        .font(ModernTheme.body.weight(.medium))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    Capsule()
                        .fill(Color.red)
                )
                .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
            } else {
                // 录音中的界面
                VStack(spacing: ModernTheme.spacing4) {
                    // 波形可视化
                    HStack(spacing: 3) {
                        ForEach(0..<audioLevels.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [ModernTheme.accent, ModernTheme.secondaryAccent],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 3, height: audioLevels[index] * 50)
                                .animation(.easeInOut(duration: 0.1), value: audioLevels[index])
                        }
                    }
                    .frame(height: 60)
                    
                    // 录音时长
                    Text(formatDuration(recordingDuration))
                        .font(ModernTheme.title2.monospacedDigit())
                        .foregroundColor(.white)
                    
                    // 提示文本
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                        Text("上滑取消")
                            .font(ModernTheme.caption)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, ModernTheme.spacing5)
                .padding(.horizontal, ModernTheme.spacing6)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ModernTheme.accent.opacity(0.95),
                                    ModernTheme.secondaryAccent.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: ModernTheme.accent.opacity(0.3), radius: 20, y: 10)
                )
            }
        }
    }
    
    // MARK: - 手势处理
    
    private func handleDragChange(_ value: DragGesture.Value) {
        // 只处理垂直方向的滑动
        let translation = value.translation.height
        
        // 向上滑动超过 80pt 时显示取消提示
        if translation < -80 {
            recordingState = .willCancel
            dragOffset = translation
        } else {
            recordingState = .recording
            dragOffset = min(0, translation) // 只允许向上滑动
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        dragOffset = 0
        
        if recordingState == .willCancel {
            // 取消录音
            cancelRecording()
        } else {
            // 完成录音
            finishRecording()
        }
    }
    
    // MARK: - 录音控制
    
    /// 启动定时器监控录音状态
    func startMonitoring() {
        recordingState = .recording
        
        // 启动定时器更新时长和波形
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            // 从 audioRecorder 获取真实数据
            recordingDuration = audioRecorder.duration
            
            // 获取音频电平
            let level = audioRecorder.getNormalizedLevel()
            audioLevels.removeFirst()
            audioLevels.append(level)
            
            // 最大录音时长 60 秒
            if recordingDuration >= 60 {
                finishRecording()
            }
        }
        
        DebugLogger.log("🎤 开始监控录音状态", level: .debug)
    }
    
    private func finishRecording() {
        timer?.invalidate()
        timer = nil
        
        isRecording = false
        recordingState = .idle
        dragOffset = 0
        
        HapticManager.notification(type: .success)
        DebugLogger.log("✅ 录音完成，时长: \(recordingDuration)s", level: .info)
        
        // 停止录音并获取文件 URL
        if let recordingURL = audioRecorder.stopRecording() {
            onRecordingComplete(recordingURL)
        }
    }
    
    private func cancelRecording() {
        timer?.invalidate()
        timer = nil
        
        isRecording = false
        recordingState = .idle
        dragOffset = 0
        
        HapticManager.notification(type: .warning)
        DebugLogger.log("❌ 录音已取消", level: .info)
        
        // 取消录音
        audioRecorder.cancelRecording()
        onCancel()
    }
    
    // MARK: - 辅助方法
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 预览

#Preview("录音中") {
    ZStack {
        ModernTheme.twilightGradient
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            Text("聊天消息区域")
                .foregroundColor(.white)
            Spacer()
        }
        
        VoiceRecorderView(
            isRecording: .constant(true),
            audioRecorder: AudioRecorderManager(),
            onRecordingComplete: { _ in },
            onCancel: {}
        )
    }
}
