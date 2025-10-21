//
//  DebugLogger.swift
//  HChat
//
//  调试日志工具 - 用于本地开发时追踪网络请求和消息流
//

import Foundation
import os.log

/// 日志级别
enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case network = "🌐 NETWORK"
    case websocket = "🔌 WEBSOCKET"
    case crypto = "🔐 CRYPTO"
}

/// 统一日志管理器
struct DebugLogger {
    
    /// 是否启用详细日志（生产环境应设为 false）
    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// 日志输出目标
    private static let logger = Logger(subsystem: "com.hchat.app", category: "debug")
    
    /// 通用日志
    static func log(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = """
        
        [\(level.rawValue)] [\(fileName):\(line)] \(function)
        📝 \(message)
        ⏰ \(Date().formatted(.iso8601))
        """
        
        print(logMessage)
        
        // 同时输出到系统日志（可在 Console.app 查看）
        switch level {
        case .error:
            logger.error("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        default:
            logger.info("\(message, privacy: .public)")
        }
    }
    
    /// WebSocket 消息日志（包含加密前后对比）
    static func logWebSocket(direction: String, message: String, encrypted: Bool = false) {
        guard isEnabled else { return }
        
        let icon = direction == "发送" ? "📤" : "📥"
        let encryptionStatus = encrypted ? "🔐 已加密" : "🔓 明文"
        
        print("""
        
        [\(LogLevel.websocket.rawValue)] \(icon) \(direction)
        \(encryptionStatus)
        💬 内容: \(message.prefix(200))\(message.count > 200 ? "..." : "")
        📏 长度: \(message.count) 字节
        ⏰ \(Date().formatted(.iso8601))
        """)
    }
    
    /// HTTP 请求日志
    static func logRequest(_ request: URLRequest) {
        guard isEnabled else { return }
        
        var headers = ""
        if let allHeaders = request.allHTTPHeaderFields {
            headers = allHeaders.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
        }
        
        var body = ""
        if let httpBody = request.httpBody,
           let bodyString = String(data: httpBody, encoding: .utf8) {
            body = "\n📦 Body:\n\(bodyString)"
        }
        
        print("""
        
        [\(LogLevel.network.rawValue)] 📤 HTTP 请求
        🎯 \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")
        📋 Headers:
        \(headers)
        \(body)
        ⏰ \(Date().formatted(.iso8601))
        """)
    }
    
    /// HTTP 响应日志
    static func logResponse(_ response: URLResponse?, data: Data?, error: Error?) {
        guard isEnabled else { return }
        
        if let error = error {
            print("""
            
            [\(LogLevel.error.rawValue)] 📥 HTTP 响应失败
            ❌ 错误: \(error.localizedDescription)
            ⏰ \(Date().formatted(.iso8601))
            """)
            return
        }
        
        guard let http = response as? HTTPURLResponse else { return }
        
        var responseBody = ""
        if let data = data,
           let bodyString = String(data: data, encoding: .utf8) {
            responseBody = "\n📦 Body:\n\(bodyString.prefix(500))\(bodyString.count > 500 ? "..." : "")"
        }
        
        let statusIcon = (200...299).contains(http.statusCode) ? "✅" : "❌"
        
        print("""
        
        [\(LogLevel.network.rawValue)] 📥 HTTP 响应
        \(statusIcon) Status: \(http.statusCode)
        🎯 URL: \(http.url?.absoluteString ?? "unknown")
        \(responseBody)
        ⏰ \(Date().formatted(.iso8601))
        """)
    }
    
    /// 加密/解密日志
    static func logCrypto(operation: String, input: String, output: String, success: Bool) {
        guard isEnabled else { return }
        
        let icon = success ? "✅" : "❌"
        
        print("""
        
        [\(LogLevel.crypto.rawValue)] \(icon) \(operation)
        📥 输入: \(input.prefix(100))...
        📤 输出: \(output.prefix(100))...
        ⏰ \(Date().formatted(.iso8601))
        """)
    }
    
    /// 保存日志到文件（用于导出和分析）
    static func exportLogs() -> URL? {
        guard isEnabled else { return nil }
        
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let logFileName = "hchat-debug-\(Date().timeIntervalSince1970).log"
        let logFileURL = documentsPath.appendingPathComponent(logFileName)
        
        // 这里可以收集所有日志并写入文件
        // 当前简化实现，实际可以维护一个日志缓冲区
        
        return logFileURL
    }
}

// MARK: - URLSession 扩展（自动记录请求）

extension URLSession {
    
    /// 带日志的 data 请求
    func dataWithLogging(for request: URLRequest) async throws -> (Data, URLResponse) {
        DebugLogger.logRequest(request)
        
        do {
            let (data, response) = try await data(for: request)
            DebugLogger.logResponse(response, data: data, error: nil)
            return (data, response)
        } catch {
            DebugLogger.logResponse(nil, data: nil, error: error)
            throw error
        }
    }
    
    /// 带日志的 upload 请求
    func uploadWithLogging(for request: URLRequest, from data: Data) async throws -> (Data, URLResponse) {
        DebugLogger.logRequest(request)
        DebugLogger.log("上传数据大小: \(data.count) 字节", level: .network)
        
        do {
            let (responseData, response) = try await upload(for: request, from: data)
            DebugLogger.logResponse(response, data: responseData, error: nil)
            return (responseData, response)
        } catch {
            DebugLogger.logResponse(nil, data: nil, error: error)
            throw error
        }
    }
}

