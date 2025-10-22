//
//  AttachmentCard.swift
//  HChat
//
//  Created on 2025-10-22.
//  附件卡片组件 - 支持图片、视频、文件、语音消息

import SwiftUI
import AVKit

struct AttachmentCard: View {
    let attachment: Attachment
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var playbackTimer: Timer?
    
    var body: some View {
        Group {
            if attachment.contentType.hasPrefix("audio/") || attachment.filename.hasSuffix(".m4a.hcss") {
                // 语音消息
                voiceMessageView
            } else if attachment.contentType.hasPrefix("image/") {
                // 图片
                imageView
            } else if attachment.contentType.hasPrefix("video/") {
                // 视频
                videoView
            } else {
                // 其他文件
                fileView
            }
        }
    }
    
    // MARK: - 语音消息视图
    
    private var voiceMessageView: some View {
        HStack(spacing: 12) {
            // 播放按钮
            Button {
                togglePlayback()
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
                ForEach(0..<30, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2, height: waveformHeight(at: index))
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
        .frame(maxWidth: 250)
        .onAppear {
            loadAudioDuration()
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    // MARK: - 图片视图
    
    private var imageView: some View {
        AsyncImage(url: URL(string: attachment.getUrl ?? "")) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 200, height: 200)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 250, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 200, height: 200)
            @unknown default:
                EmptyView()
            }
        }
    }
    
    // MARK: - 视频视图
    
    private var videoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = URL(string: attachment.getUrl ?? "") {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            Text(attachment.filename)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: 250)
    }
    
    // MARK: - 文件视图
    
    private var fileView: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.filename)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                if let size = attachment.sizeBytes {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                // TODO: 下载文件
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 250)
    }
    
    // MARK: - 辅助方法
    
    private func waveformHeight(at index: Int) -> CGFloat {
        // 生成伪随机但一致的波形高度
        let seed = Double(attachment.filename.hashValue + index)
        let normalized = abs(sin(seed)) * 0.6 + 0.4 // 0.4 - 1.0 范围
        return normalized * 24
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
    
    // MARK: - 音频播放
    
    private func loadAudioDuration() {
        guard let url = URL(string: attachment.getUrl ?? "") else { return }
        
        // TODO: 下载并解密音频文件
        // 暂时设置一个估计值
        duration = 10.0 // 示例时长
    }
    
    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        // TODO: 实现真实的音频播放
        // 这需要下载并解密文件
        isPlaying = true
        currentTime = 0
        
        // 模拟播放进度
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime += 0.1
            if currentTime >= duration {
                stopPlayback()
            }
        }
        
        HapticManager.impact(style: .light)
    }
    
    private func pausePlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        HapticManager.impact(style: .light)
    }
    
    private func stopPlayback() {
        isPlaying = false
        currentTime = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

