//
//  AudioPlayerManager.swift
//  HChat
//
//  Created on 2025-10-22.
//  音频播放管理器 - 支持加密音频的下载、解密和播放

import Foundation
import AVFoundation
import UIKit

@MainActor
@Observable
class AudioPlayerManager: NSObject {
    
    // MARK: - 属性
    
    /// 当前播放的音频 ID（通常是 attachment 的 getUrl）
    private(set) var currentPlayingId: String?
    
    /// 播放状态
    private(set) var isPlaying = false
    
    /// 当前播放时间
    private(set) var currentTime: TimeInterval = 0
    
    /// 总时长
    private(set) var duration: TimeInterval = 0
    
    /// 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    /// 播放进度定时器
    private var playbackTimer: Timer?
    
    /// 本地缓存目录
    private let cacheDirectory: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("AudioCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()
    
    // MARK: - 公共方法
    
    /// 播放或暂停音频
    /// - Parameters:
    ///   - audioId: 音频唯一标识（通常是 getUrl）
    ///   - url: 音频下载 URL
    ///   - passphrase: 解密密钥
    func togglePlayback(audioId: String, url: String, passphrase: String) async {
        // 如果是同一个音频
        if currentPlayingId == audioId {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }
        
        // 播放新音频，先停止当前播放
        stop()
        currentPlayingId = audioId
        
        do {
            // 下载并解密音频
            let localURL = try await downloadAndDecryptAudio(from: url, passphrase: passphrase, audioId: audioId)
            
            // 播放
            try play(localURL: localURL)
        } catch {
            DebugLogger.log("❌ 播放失败: \(error.localizedDescription)", level: .error)
            currentPlayingId = nil
        }
    }
    
    /// 停止播放
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        isPlaying = false
        currentTime = 0
        duration = 0
        currentPlayingId = nil
        
        DebugLogger.log("⏹️ 停止播放", level: .info)
    }
    
    /// 暂停播放
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        HapticManager.impact(style: .light)
        DebugLogger.log("⏸️ 暂停播放", level: .info)
    }
    
    /// 继续播放
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
        
        HapticManager.impact(style: .light)
        DebugLogger.log("▶️ 继续播放", level: .info)
    }
    
    /// 检查是否正在播放指定音频
    func isPlayingAudio(id: String) -> Bool {
        return currentPlayingId == id && isPlaying
    }
    
    // MARK: - 私有方法
    
    /// 下载并解密音频
    private func downloadAndDecryptAudio(from urlString: String, passphrase: String, audioId: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw AudioPlayerError.invalidURL
        }
        
        // 检查缓存（使用 audioId 的 hash 作为文件名，避免 URL 太长）
        let cacheFileName = "audio_\(abs(audioId.hashValue))"
        let cachedURL = cacheDirectory.appendingPathComponent(cacheFileName + ".m4a")
        
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            DebugLogger.log("✅ 使用缓存音频: \(cachedURL.lastPathComponent)", level: .info)
            return cachedURL
        }
        
        DebugLogger.log("⬇️ 开始下载音频...", level: .info)
        
        // 下载加密文件
        let (encryptedURL, _) = try await URLSession.shared.download(from: url)
        
        DebugLogger.log("🔓 开始解密音频...", level: .info)
        
        // 解密
        let decryptedURL = try await UploadManager.downloadAndDecryptToTemp(
            from: encryptedURL,
            passphrase: passphrase
        )
        
        // 移动到缓存目录
        try FileManager.default.moveItem(at: decryptedURL, to: cachedURL)
        
        DebugLogger.log("✅ 音频已缓存: \(cachedURL.lastPathComponent)", level: .info)
        
        return cachedURL
    }
    
    /// 播放本地音频文件
    private func play(localURL: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: localURL)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        
        isPlaying = true
        duration = audioPlayer?.duration ?? 0
        currentTime = 0
        
        startTimer()
        
        HapticManager.impact(style: .light)
        DebugLogger.log("▶️ 开始播放: \(localURL.lastPathComponent)", level: .info)
    }
    
    /// 启动播放进度计时器
    private func startTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
            }
        }
    }
    
    // MARK: - 错误类型
    
    enum AudioPlayerError: Error {
        case invalidURL
        case downloadFailed
        case decryptionFailed
        case playbackFailed
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            DebugLogger.log("✅ 播放完成", level: .info)
            self.stop()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            DebugLogger.log("❌ 播放出错: \(error?.localizedDescription ?? "unknown")", level: .error)
            self.stop()
        }
    }
}

