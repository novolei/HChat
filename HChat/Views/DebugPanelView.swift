//
//  DebugPanelView.swift
//  HChat
//
//  开发者调试面板 - 用于本地开发时切换环境、查看日志、模拟网络问题
//

import SwiftUI

struct DebugPanelView: View {
    @State private var selectedEnvironment = AppEnvironment.current
    @State private var verboseLogging = AppEnvironment.verboseLogging
    @State private var simulateDelay = AppEnvironment.simulateNetworkDelay
    @State private var delaySeconds = AppEnvironment.networkDelaySeconds
    @State private var showConnectionStatus = false
    
    var body: some View {
        #if DEBUG
        NavigationView {
            List {
                // 环境选择
                Section {
                    Picker("环境", selection: $selectedEnvironment) {
                        ForEach(EnvironmentType.allCases, id: \.self) { env in
                            Text("\(env.emoji) \(env.rawValue)")
                                .tag(env)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedEnvironment) { newValue in
                        AppEnvironment.current = newValue
                    }
                    
                    // 当前环境信息
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "API Base", value: AppEnvironment.apiBaseURL.absoluteString)
                        InfoRow(label: "WebSocket", value: AppEnvironment.chatWebSocketURL.absoluteString)
                        InfoRow(label: "S3 Bucket", value: AppEnvironment.s3BucketName)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("🌍 环境配置")
                }
                
                // 日志配置
                Section {
                    Toggle("详细日志", isOn: $verboseLogging)
                        .onChange(of: verboseLogging) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "verboseLogging")
                        }
                    
                    Button("打印环境信息") {
                        AppEnvironment.printEnvironmentInfo()
                    }
                    
                    Button("查看系统日志") {
                        openConsoleApp()
                    }
                } header: {
                    Text("📊 日志管理")
                } footer: {
                    Text("详细日志会在 Xcode 控制台和系统 Console.app 中显示")
                }
                
                // 网络模拟
                Section {
                    Toggle("模拟网络延迟", isOn: $simulateDelay)
                        .onChange(of: simulateDelay) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "simulateNetworkDelay")
                        }
                    
                    if simulateDelay {
                        HStack {
                            Text("延迟时间")
                            Slider(value: $delaySeconds, in: 0...5, step: 0.5)
                            Text("\(delaySeconds, specifier: "%.1f")s")
                                .frame(width: 50)
                        }
                        .onChange(of: delaySeconds) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "networkDelaySeconds")
                        }
                    }
                } header: {
                    Text("🐢 网络模拟")
                } footer: {
                    Text("模拟慢速网络，测试加载状态和超时处理")
                }
                
                // 连接测试
                Section {
                    Button("测试 API 连接") {
                        testAPIConnection()
                    }
                    
                    Button("测试 WebSocket 连接") {
                        testWebSocketConnection()
                    }
                    
                    Button("测试 MinIO 上传") {
                        testMinIOUpload()
                    }
                    
                    if showConnectionStatus {
                        Text("连接测试结果会显示在控制台")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("🔍 连接测试")
                }
                
                // 快捷操作
                Section {
                    Button("清空消息缓存") {
                        clearMessageCache()
                    }
                    
                    Button("清空用户设置") {
                        clearUserDefaults()
                    }
                    .foregroundColor(.red)
                    
                    Button("重启 WebSocket") {
                        restartWebSocket()
                    }
                } header: {
                    Text("🛠 快捷操作")
                }
                
                // Backend 状态
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VPS 服务器: hc.go-lv.com")
                            .font(.caption)
                        Text("Docker Compose 服务:")
                            .font(.caption.bold())
                            .padding(.top, 4)
                        
                        ServiceStatusRow(name: "chat-gateway", port: "10080", status: .running)
                        ServiceStatusRow(name: "message-service", port: "10081", status: .running)
                        ServiceStatusRow(name: "minio", port: "10090/10091", status: .running)
                        ServiceStatusRow(name: "livekit", port: "17880", status: .running)
                        ServiceStatusRow(name: "coturn", port: "14788", status: .running)
                    }
                    .font(.caption)
                } header: {
                    Text("🖥 Backend 状态")
                } footer: {
                    Text("所有服务运行在远程 VPS 上")
                }
            }
            .navigationTitle("🔧 开发者工具")
            .navigationBarTitleDisplayMode(.inline)
        }
        #else
        EmptyView()
        #endif
    }
    
    // MARK: - 辅助视图
    
    private struct InfoRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label + ":")
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
    
    private struct ServiceStatusRow: View {
        let name: String
        let port: String
        let status: ServiceStatus
        
        var body: some View {
            HStack {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                Text(name)
                Spacer()
                Text(":\(port)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private enum ServiceStatus {
        case running, stopped, unknown
        
        var color: Color {
            switch self {
            case .running: return .green
            case .stopped: return .red
            case .unknown: return .gray
            }
        }
    }
    
    // MARK: - 测试方法
    
    private func testAPIConnection() {
        showConnectionStatus = true
        Task {
            do {
                let url = AppEnvironment.apiBaseURL.appendingPathComponent("/api/health")
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                
                DebugLogger.log("🔍 测试 API 连接: \(url.absoluteString)", level: .info)
                let (data, response) = try await URLSession.shared.dataWithLogging(for: request)
                
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    DebugLogger.log("✅ API 连接成功", level: .info)
                } else {
                    DebugLogger.log("❌ API 返回异常状态码", level: .warning)
                }
            } catch {
                DebugLogger.log("❌ API 连接失败: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func testWebSocketConnection() {
        DebugLogger.log("🔍 测试 WebSocket 连接: \(AppEnvironment.chatWebSocketURL.absoluteString)", level: .info)
        DebugLogger.log("提示: WebSocket 连接测试需要在聊天界面查看", level: .info)
    }
    
    private func testMinIOUpload() {
        showConnectionStatus = true
        Task {
            do {
                DebugLogger.log("🔍 测试 MinIO 预签名 URL 请求", level: .info)
                let testKey = "test/debug-\(Date().timeIntervalSince1970).txt"
                let response = try await Services.minio.presign(objectKey: testKey, contentType: "text/plain")
                DebugLogger.log("✅ MinIO 预签名 URL 获取成功\nPUT: \(response.putUrl)\nGET: \(response.getUrl)", level: .info)
            } catch {
                DebugLogger.log("❌ MinIO 测试失败: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func clearMessageCache() {
        DebugLogger.log("🗑 清空消息缓存", level: .info)
        // TODO: 实现清空逻辑
    }
    
    private func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        DebugLogger.log("🗑 用户设置已清空", level: .warning)
    }
    
    private func restartWebSocket() {
        DebugLogger.log("🔄 重启 WebSocket 连接", level: .info)
        NotificationCenter.default.post(name: NSNotification.Name("RestartWebSocket"), object: nil)
    }
    
    private func openConsoleApp() {
        DebugLogger.log("💡 提示: 打开 macOS Console.app，搜索 'com.hchat.app' 查看系统日志", level: .info)
    }
}

// MARK: - 预览

#if DEBUG
struct DebugPanelView_Previews: PreviewProvider {
    static var previews: some View {
        DebugPanelView()
    }
}
#endif

