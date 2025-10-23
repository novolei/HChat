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
        .allowsHitTesting(isRecording)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                // 开始录音时启动监控
                DebugLogger.log("🎬 VoiceRecorderView: 开始监控录音", level: .info)
                startMonitoring()
            } else {
                // 停止录音时清理定时器
                DebugLogger.log("🛑 VoiceRecorderView: 停止监控", level: .info)
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
                    // 波形可视化 - 使用白色和黄绿色渐变，更明显
                    HStack(spacing: 2) {
                        ForEach(0..<audioLevels.count, id: \.self) { index in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white, Color(red: 0.5, green: 1.0, blue: 0.5)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 2.5, height: max(8, audioLevels[index] * 70))
                                .shadow(color: Color.white.opacity(0.5), radius: 2)
                                .animation(.easeInOut(duration: 0.15), value: audioLevels[index])
                        }
                    }
                    .frame(height: 70)
                    
                    // 录音时长
                    Text(formatDuration(recordingDuration))
                        .font(ModernTheme.title2.monospacedDigit())
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                    
                    // 提示文本
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                        Text("上滑取消")
                            .font(ModernTheme.caption)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .padding(.vertical, ModernTheme.spacing5)
                .padding(.horizontal, 40) // 增加水平内边距，让面板更宽
                .frame(maxWidth: 340) // 设置最大宽度
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.4, blue: 0.9).opacity(0.95), // 深蓝色
                                    Color(red: 0.5, green: 0.3, blue: 0.8).opacity(0.95)  // 紫色
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
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
        
        DebugLogger.log("🎤 开始监控录音状态，isRecording=\(audioRecorder.isRecording)", level: .info)
        
        // 启动定时器更新时长和波形
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            // 从 audioRecorder 获取真实数据
            let newDuration = audioRecorder.duration
            let newLevel = audioRecorder.getNormalizedLevel()
            
            // 更新时长
            recordingDuration = newDuration
            
            // 更新音频电平
            audioLevels.removeFirst()
            audioLevels.append(newLevel)
            
            // 偶尔输出日志
            if Int(newDuration * 10) % 10 == 0 {
                DebugLogger.log("📊 录音中: \(newDuration)s, level=\(newLevel)", level: .debug)
            }
            
            // 最大录音时长 60 秒
            if recordingDuration >= 60 {
                finishRecording()
            }
        }
        
        DebugLogger.log("✅ 定时器已启动", level: .info)
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
