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
    var onRecordingComplete: (URL) -> Void
    var onCancel: () -> Void
    
    @State private var recordingState: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 30)
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 录音界面背景遮罩
                if isRecording {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                VStack {
                    Spacer()
                    
                    if isRecording {
                        // 录音控制面板
                        recordingPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isRecording)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: recordingState)
    }
    
    // MARK: - 录音控制面板
    
    private var recordingPanel: some View {
        VStack(spacing: ModernTheme.spacing4) {
            // 提示文本
            HStack(spacing: 8) {
                if recordingState == .willCancel {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("松手取消")
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(ModernTheme.accent)
                    Text("上滑取消")
                        .foregroundColor(ModernTheme.primaryText)
                }
            }
            .font(ModernTheme.subheadline)
            .padding(.vertical, ModernTheme.spacing2)
            
            // 波形可视化
            HStack(spacing: 3) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(recordingState == .willCancel ? Color.red : ModernTheme.accent)
                        .frame(width: 3, height: audioLevels[index] * 40)
                        .animation(.easeInOut(duration: 0.1), value: audioLevels[index])
                }
            }
            .frame(height: 50)
            .padding(.vertical, ModernTheme.spacing3)
            
            // 录音时长
            Text(formatDuration(recordingDuration))
                .font(ModernTheme.title2.monospacedDigit())
                .foregroundColor(recordingState == .willCancel ? .red : ModernTheme.primaryText)
            
            // 录音按钮
            recordButton
        }
        .padding(.horizontal, ModernTheme.spacing5)
        .padding(.vertical, ModernTheme.spacing5)
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.extraLargeRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, ModernTheme.spacing4)
        .padding(.bottom, ModernTheme.spacing5)
    }
    
    // MARK: - 录音按钮
    
    private var recordButton: some View {
        Circle()
            .fill(recordingState == .willCancel ? Color.red : ModernTheme.accent)
            .frame(width: 70, height: 70)
            .overlay(
                Image(systemName: recordingState == .willCancel ? "xmark" : "waveform")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            )
            .scaleEffect(recordingState == .recording ? 1.1 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChange(value)
                    }
                    .onEnded { value in
                        handleDragEnd(value)
                    }
            )
    }
    
    // MARK: - 手势处理
    
    private func handleDragChange(_ value: DragGesture.Value) {
        if !isRecording {
            // 开始录音
            startRecording()
        }
        
        // 检查是否向上滑动超过阈值
        if value.translation.height < -50 {
            recordingState = .willCancel
        } else {
            recordingState = .recording
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        if recordingState == .willCancel {
            // 取消录音
            cancelRecording()
        } else {
            // 完成录音
            finishRecording()
        }
    }
    
    // MARK: - 录音控制
    
    private func startRecording() {
        isRecording = true
        recordingState = .recording
        recordingDuration = 0
        
        // 启动定时器更新时长和波形
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
            updateAudioLevels()
            
            // 最大录音时长 60 秒
            if recordingDuration >= 60 {
                finishRecording()
            }
        }
        
        HapticManager.impact(style: .medium)
        DebugLogger.log("🎤 开始录音", level: .info)
    }
    
    private func updateAudioLevels() {
        // 模拟音频电平变化（实际应从 AVAudioRecorder 获取）
        let newLevel = CGFloat.random(in: 0.2...1.0)
        audioLevels.removeFirst()
        audioLevels.append(newLevel)
    }
    
    private func finishRecording() {
        timer?.invalidate()
        timer = nil
        
        isRecording = false
        recordingState = .idle
        
        HapticManager.notification(type: .success)
        DebugLogger.log("✅ 录音完成，时长: \(recordingDuration)s", level: .info)
        
        // TODO: 返回录音文件 URL
        // onRecordingComplete(recordingURL)
    }
    
    private func cancelRecording() {
        timer?.invalidate()
        timer = nil
        
        isRecording = false
        recordingState = .idle
        
        HapticManager.notification(type: .warning)
        DebugLogger.log("❌ 录音已取消", level: .info)
        
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

#Preview("录音界面") {
    ZStack {
        ModernTheme.twilightGradient
            .ignoresSafeArea()
        
        VoiceRecorderView(
            isRecording: .constant(true),
            onRecordingComplete: { _ in },
            onCancel: {}
        )
    }
}

