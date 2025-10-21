//
//  AppEnvironment.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation

/// 环境类型
enum EnvironmentType: String, CaseIterable {
    case production = "生产环境"
    case development = "开发环境"
    case local = "本地测试"
    
    var emoji: String {
        switch self {
        case .production: return "🚀"
        case .development: return "🔧"
        case .local: return "💻"
        }
    }
}

/// 全局环境管理器
final class AppEnvironment {
    
    // MARK: - 当前环境配置
    
    /// 当前激活的环境（可在设置中切换）
    static var current: EnvironmentType {
        get {
            #if DEBUG
            // 开发模式下允许切换环境
            if let saved = UserDefaults.standard.string(forKey: "selectedEnvironment"),
               let env = EnvironmentType(rawValue: saved) {
                return env
            }
            return .development  // 默认开发环境
            #else
            return .production   // 发布版强制生产环境
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedEnvironment")
            NotificationCenter.default.post(name: .environmentDidChange, object: nil)
            DebugLogger.log("环境已切换到: \(newValue.emoji) \(newValue.rawValue)", level: .info)
            #endif
        }
    }
    
    // MARK: - 环境配置
    
    static var apiBaseURL: URL {
        switch current {
        case .production:
            return URL(string: "https://hc.go-lv.com")!
        case .development:
            return URL(string: "https://hc.go-lv.com")!  // VPS 地址
        case .local:
            // 本地测试服务器（如果您在本地运行 Docker Compose）
            return URL(string: "http://localhost:10081")!
        }
    }
    
    static var chatWebSocketURL: URL {
        switch current {
        case .production:
            return URL(string: "wss://hc.go-lv.com/chat-ws")!
        case .development:
            return URL(string: "wss://hc.go-lv.com/chat-ws")!  // VPS WebSocket
        case .local:
            return URL(string: "ws://localhost:10080/chat-ws")!
        }
    }
    
    static var s3BucketName: String {
        switch current {
        case .production:
            return "hc-attachments"
        case .development:
            return "hc-attachments-dev"  // 可以使用不同的桶
        case .local:
            return "hc-attachments-local"
        }
    }
    
    static var s3Endpoint: URL {
        switch current {
        case .production, .development:
            return URL(string: "https://s3.hc.go-lv.com")!
        case .local:
            return URL(string: "http://localhost:10090")!
        }
    }
    
    // MARK: - 调试配置
    
    /// 是否启用详细日志
    static var verboseLogging: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "verboseLogging")
        #else
        return false
        #endif
    }
    
    /// 是否模拟网络延迟（用于测试）
    static var simulateNetworkDelay: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "simulateNetworkDelay")
        #else
        return false
        #endif
    }
    
    /// 模拟的网络延迟（秒）
    static var networkDelaySeconds: Double {
        #if DEBUG
        return UserDefaults.standard.double(forKey: "networkDelaySeconds")
        #else
        return 0
        #endif
    }
    
    // MARK: - 辅助方法
    
    /// 打印当前环境信息
    static func printEnvironmentInfo() {
        DebugLogger.log("""
        
        ============ 环境信息 ============
        \(current.emoji) 当前环境: \(current.rawValue)
        🌐 API Base: \(apiBaseURL.absoluteString)
        🔌 WebSocket: \(chatWebSocketURL.absoluteString)
        🪣 S3 Bucket: \(s3BucketName)
        📊 详细日志: \(verboseLogging ? "✅" : "❌")
        🐢 网络延迟: \(simulateNetworkDelay ? "\(networkDelaySeconds)s" : "关闭")
        ================================
        
        """, level: .info)
    }
}

// MARK: - 通知

extension Notification.Name {
    static let environmentDidChange = Notification.Name("environmentDidChange")
}

// MARK: - 服务单例

/// 方便在 App 各处取到"单例"服务
enum Services {
    static var minio: MinIOService {
        MinIOService(baseApi: AppEnvironment.apiBaseURL)
    }
    
    static var uploader: UploadManager {
        UploadManager(minio: minio)
    }
}
