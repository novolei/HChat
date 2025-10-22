//
//  VoiceMessagePlayer.swift
//  HChat
//
//  Created on 2025-10-22.
//  语音消息播放器组件

import SwiftUI
import AVFoundation

/// 语音消息播放器（用于消息气泡中）
struct VoiceMessagePlayer: View {
    let isPlaying: Bool          // 播放状态（从外部传入）
    let currentTime: TimeInterval // 当前播放时间（从外部传入）
    let duration: TimeInterval    // 总时长（从外部传入）
    let waveformData: [CGFloat]   // 波形数据
    let onPlay: () -> Void
    
    // 播放进度（0.0 - 1.0）
    private var playbackProgress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 播放按钮
            Button {
                onPlay()
                HapticManager.impact(style: .light)
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    )
            }
            .buttonStyle(.plain)
            
            // 波形可视化 + 播放进度
            HStack(spacing: 2) {
                ForEach(0..<min(waveformData.count, 30), id: \.self) { index in
                    let progress = playbackProgress * CGFloat(waveformData.count)
                    let isPlayed = CGFloat(index) < progress
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            // 已播放部分：完全不透明；未播放部分：30% 透明
                            Color.white.opacity(isPlayed ? 0.9 : 0.3)
                        )
                        .frame(width: 2, height: max(4, waveformData[index] * 24))
                        .animation(.linear(duration: 0.1), value: isPlayed)
                }
            }
            .frame(height: 28)
            
            // 时长显示
            Text(formatDuration(isPlaying ? currentTime : duration))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// 语音消息输入预览（录音完成后在输入框显示）
struct VoiceMessagePreview: View {
    let duration: TimeInterval
    let waveformData: [CGFloat]
    let audioURL: URL  // 音频文件路径
    let onSend: () -> Void
    let onCancel: () -> Void
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var playbackTimer: Timer?
    
    // 播放进度（0.0 - 1.0）
    private var playbackProgress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 波形可视化 + 播放/暂停按钮 + 进度指示
            ZStack(alignment: .leading) {
                // 播放进度遮罩（已播放部分高亮）
                HStack(spacing: 2) {
                    ForEach(0..<min(waveformData.count, 40), id: \.self) { index in
                        let progress = playbackProgress * CGFloat(waveformData.count)
                        let isPlayed = CGFloat(index) < progress
                        
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: isPlayed 
                                        ? [ModernTheme.accent, ModernTheme.secondaryAccent]
                                        : [ModernTheme.accent.opacity(0.3), ModernTheme.secondaryAccent.opacity(0.3)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3, height: max(4, waveformData[index] * 32))
                            .animation(.linear(duration: 0.1), value: isPlayed)
                    }
                }
                .frame(height: 40)
                .contentShape(Rectangle()) // 确保整个区域可点击
                .onTapGesture {
                    handleTap()
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    handleLongPress()
                }
                
                // 播放/暂停按钮（始终显示，提示用户可以播放）
                Button {
                    handleTap()
                } label: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.accent.opacity(0.9), ModernTheme.secondaryAccent.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 1.5)
                        )
                        .shadow(color: ModernTheme.accent.opacity(0.4), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
            
            // 时长显示
            Text(formatDuration(isPlaying ? currentTime : duration))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(ModernTheme.primaryText)
                .monospacedDigit()
            
            Spacer()
            
            // 取消按钮
            Button {
                stopPlayback()
                onCancel()
                HapticManager.impact(style: .light)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ModernTheme.tertiaryText)
            }
            .buttonStyle(.plain)
            
            // 发送按钮
            Button {
                stopPlayback()
                onSend()
                HapticManager.impact(style: .medium)
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.accent, ModernTheme.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.extraLargeRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModernTheme.extraLargeRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [ModernTheme.accent.opacity(0.3), ModernTheme.secondaryAccent.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .onDisappear {
            stopPlayback()
        }
    }
    
    // MARK: - 试听控制
    
    /// 处理轻点：播放/暂停
    private func handleTap() {
        if isPlaying {
            pausePlayback()
        } else {
            if currentTime > 0 {
                resumePlayback()
            } else {
                startPlayback()
            }
        }
    }
    
    /// 处理长按：停止播放
    private func handleLongPress() {
        stopPlayback()
        HapticManager.impact(style: .medium)
        DebugLogger.log("⏹️ 长按停止试听", level: .info)
    }
    
    /// 开始播放
    private func startPlayback() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            currentTime = 0
            
            // 启动计时器更新进度
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
                if let player = audioPlayer {
                    currentTime = player.currentTime
                    
                    // 播放完成
                    if !player.isPlaying {
                        stopPlayback()
                    }
                }
            }
            
            HapticManager.impact(style: .light)
            DebugLogger.log("▶️ 开始试听", level: .info)
        } catch {
            DebugLogger.log("❌ 试听失败: \(error.localizedDescription)", level: .error)
        }
    }
    
    /// 暂停播放
    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        HapticManager.impact(style: .light)
        DebugLogger.log("⏸️ 暂停试听", level: .info)
    }
    
    /// 继续播放
    private func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
        
        // 重新启动计时器
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            if let player = audioPlayer {
                currentTime = player.currentTime
                
                if !player.isPlaying {
                    stopPlayback()
                }
            }
        }
        
        HapticManager.impact(style: .light)
        DebugLogger.log("▶️ 继续试听", level: .info)
    }
    
    /// 停止播放
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        DebugLogger.log("⏹️ 停止试听", level: .info)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 预览

#Preview("播放器") {
    ZStack {
        LinearGradient(
            colors: [ModernTheme.accent, ModernTheme.secondaryAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            // 消息气泡中的播放器
            VoiceMessagePlayer(
                isPlaying: false,
                currentTime: 0,
                duration: 23,
                waveformData: (0..<30).map { _ in CGFloat.random(in: 0.2...1.0) },
                onPlay: {}
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.2))
            )
            .frame(maxWidth: 300)
            
            // 输入框预览（需要临时音频文件用于预览）
            // VoiceMessagePreview 需要 audioURL 参数
            Text("预览需要真实音频文件")
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
    }
}

