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
    let duration: TimeInterval
    let waveformData: [CGFloat] // 波形数据
    let onPlay: () -> Void
    
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // 播放按钮
            Button {
                isPlaying.toggle()
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
            
            // 波形可视化
            HStack(spacing: 2) {
                ForEach(0..<min(waveformData.count, 30), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2, height: max(4, waveformData[index] * 24))
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
    let onSend: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 波形可视化
            HStack(spacing: 2) {
                ForEach(0..<min(waveformData.count, 40), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.accent, ModernTheme.secondaryAccent],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3, height: max(4, waveformData[index] * 32))
                }
            }
            .frame(height: 40)
            
            // 时长显示
            Text(formatDuration(duration))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(ModernTheme.primaryText)
                .monospacedDigit()
            
            Spacer()
            
            // 取消按钮
            Button {
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
            
            // 输入框预览
            VoiceMessagePreview(
                duration: 23,
                waveformData: (0..<40).map { _ in CGFloat.random(in: 0.2...1.0) },
                onSend: {},
                onCancel: {}
            )
        }
        .padding()
    }
}

