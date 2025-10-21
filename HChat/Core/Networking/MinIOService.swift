//
//  MinIOService.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation

struct MinIOService {
    let baseApi: URL   // https://hc.go-lv.com

    func presign(objectKey: String, contentType: String) async throws -> PresignResponse {
        DebugLogger.log("🎯 请求预签名 URL: \(objectKey)", level: .network)
        
        var req = URLRequest(url: baseApi.appendingPathComponent("/api/attachments/presign"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["objectKey": objectKey, "contentType": contentType]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 使用带日志的请求方法
        let (data, resp) = try await URLSession.shared.dataWithLogging(for: req)
        
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            DebugLogger.log("❌ 预签名请求失败: HTTP \(statusCode)", level: .error)
            throw URLError(.badServerResponse)
        }
        
        let response = try JSONDecoder().decode(PresignResponse.self, from: data)
        DebugLogger.log("✅ 预签名 URL 获取成功\n  PUT: \(response.putUrl)\n  GET: \(response.getUrl)", level: .network)
        
        return response
    }

    func upload(putUrl: URL, data: Data, contentType: String) async throws {
        DebugLogger.log("📤 开始上传文件到 MinIO: \(data.count) 字节", level: .network)
        
        var req = URLRequest(url: putUrl)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let startTime = Date()
        let (_, resp) = try await URLSession.shared.uploadWithLogging(for: req, from: data)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            DebugLogger.log("❌ 文件上传失败: HTTP \(statusCode)", level: .error)
            throw URLError(.cannotCreateFile)
        }
        
        let speedMBps = Double(data.count) / duration / 1024 / 1024
        DebugLogger.log("✅ 文件上传成功 - 耗时: \(String(format: "%.2f", duration))s, 速度: \(String(format: "%.2f", speedMBps)) MB/s", level: .network)
    }
}
