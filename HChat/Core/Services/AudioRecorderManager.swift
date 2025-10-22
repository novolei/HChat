//
//  AudioRecorderManager.swift
//  HChat
//
//  Created on 2025-10-22.
//  音频录制管理器

import Foundation
import AVFoundation

@MainActor
@Observable
class AudioRecorderManager: NSObject {
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    private(set) var isRecording = false
    private(set) var currentLevel: Float = 0.0
    private(set) var duration: TimeInterval = 0
    
    private var levelTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // 不在初始化时配置音频会话，避免锁屏时报错
        // 音频会话将在 startRecording() 时按需配置
    }
    
    // MARK: - Audio Session Setup
    
    /// 配置并激活音频会话（仅在需要时调用）
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            DebugLogger.log("✅ 音频会话已激活", level: .info)
        } catch {
            DebugLogger.log("❌ 音频会话激活失败: \(error.localizedDescription)", level: .error)
            throw AudioRecorderError.audioSessionFailed
        }
    }
    
    /// 停用音频会话（录音结束后）
    private func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            DebugLogger.log("✅ 音频会话已停用", level: .debug)
        } catch {
            DebugLogger.log("⚠️ 音频会话停用失败: \(error.localizedDescription)", level: .warning)
        }
    }
    
    // MARK: - Recording Control
    
    /// 请求麦克风权限
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// 开始录音
    func startRecording() throws {
        // 激活音频会话
        try setupAudioSession()
        
        // 生成临时文件 URL
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "voice_\(UUID().uuidString).m4a"
        recordingURL = tempDir.appendingPathComponent(filename)
        
        guard let url = recordingURL else {
            throw AudioRecorderError.invalidURL
        }
        
        // 配置录音设置
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // 创建录音器
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        // 开始录音
        guard audioRecorder?.record() == true else {
            deactivateAudioSession()
            throw AudioRecorderError.recordingFailed
        }
        
        isRecording = true
        duration = 0
        
        // 启动音量监测定时器
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeters()
            }
        }
        
        DebugLogger.log("🎤 开始录音: \(filename)", level: .info)
    }
    
    /// 停止录音
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        levelTimer?.invalidate()
        levelTimer = nil
        
        isRecording = false
        currentLevel = 0
        
        // 停用音频会话
        deactivateAudioSession()
        
        DebugLogger.log("⏹️ 停止录音，时长: \(duration)s", level: .info)
        
        return recordingURL
    }
    
    /// 取消录音
    func cancelRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        levelTimer?.invalidate()
        levelTimer = nil
        
        isRecording = false
        currentLevel = 0
        duration = 0
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingURL = nil
        
        // 停用音频会话
        deactivateAudioSession()
        
        DebugLogger.log("❌ 取消录音", level: .info)
    }
    
    // MARK: - Metering
    
    private func updateMeters() {
        audioRecorder?.updateMeters()
        
        if let recorder = audioRecorder {
            // 获取平均功率 (-160 到 0)
            let avgPower = recorder.averagePower(forChannel: 0)
            // 归一化到 0-1
            currentLevel = pow(10, avgPower / 20)
            duration = recorder.currentTime
        }
    }
    
    /// 获取归一化的音量等级（0.0 - 1.0）
    func getNormalizedLevel() -> CGFloat {
        return CGFloat(max(0.1, min(1.0, currentLevel * 2)))
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                DebugLogger.log("✅ 录音文件保存成功", level: .info)
            } else {
                DebugLogger.log("❌ 录音文件保存失败", level: .error)
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                DebugLogger.log("❌ 录音编码错误: \(error.localizedDescription)", level: .error)
            }
        }
    }
}

// MARK: - Errors

enum AudioRecorderError: Error {
    case invalidURL
    case recordingFailed
    case permissionDenied
    case audioSessionFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的录音文件路径"
        case .recordingFailed:
            return "录音失败"
        case .permissionDenied:
            return "未授权麦克风权限"
        case .audioSessionFailed:
            return "音频会话配置失败"
        }
    }
}

