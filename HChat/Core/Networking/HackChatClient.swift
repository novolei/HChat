//
//  HackChatClient.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  重构版本：专注于 WebSocket 连接管理和 API 暴露
//

import Foundation
import Observation

@MainActor
@Observable
final class HackChatClient {
    // MARK: - 状态管理（委托给 ChatState）
    let state: ChatState
    
    // 为了向下兼容，暴露 state 的属性
    var channels: [Channel] { state.channels }
    var currentChannel: String {
        get { state.currentChannel }
        set { state.currentChannel = newValue }
    }
    var messagesByChannel: [String: [ChatMessage]] { state.messagesByChannel }
    var myNick: String {
        get { state.myNick }
        set { state.myNick = newValue }
    }
    var passphraseForEndToEndEncryption: String {
        get { state.passphraseForEndToEndEncryption }
        set { state.passphraseForEndToEndEncryption = newValue }
    }
    var onlineByRoom: [String: Set<String>] { state.onlineByRoom }
    var onlineCountByRoom: [String: Int] { state.onlineCountByRoom }
    var shouldShowNicknamePrompt: Bool { state.shouldShowNicknamePrompt }
    
    // MARK: - 处理器
    private var messageHandler: MessageHandler!
    private var commandHandler: CommandHandler!
    
    // MARK: - WebSocket
    private var webSocket: URLSessionWebSocketTask?
    
    // MARK: - 初始化
    init() {
        self.state = ChatState()
        self.messageHandler = MessageHandler(state: state)
        self.commandHandler = CommandHandler(state: state, sendMessage: { [weak self] json in
            self?.send(json: json)
        })
    }
    
    // MARK: - 连接管理
    
    func connect(to url: URL) {
        DebugLogger.log("🔌 连接 WebSocket: \(url.absoluteString)", level: .websocket)
        
        let task = URLSession.shared.webSocketTask(with: url)
        self.webSocket = task
        task.resume()
        
        // 发送初始命令
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            DebugLogger.log("👤 设置昵称: \(state.myNick)", level: .websocket)
            send(json: ["type": "nick", "nick": state.myNick])
            DebugLogger.log("🚪 加入频道: \(state.currentChannel)", level: .websocket)
            send(json: ["type": "join", "room": state.currentChannel])
            send(json: ["type": "who", "room": state.currentChannel])
        }
        
        // 周期性刷新在线列表
        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.send(json: ["type": "who", "room": self.state.currentChannel])
        }
        
        listen()
    }
    
    func disconnect() {
        DebugLogger.log("🔌 断开 WebSocket 连接", level: .websocket)
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
    
    // MARK: - 发送消息
    
    func sendText(_ text: String) {
        // 检查是否是命令
        if let cmd = CommandParser.parse(text) {
            commandHandler.handle(cmd)
            return
        }
        
        // 发送普通消息
        let id = UUID().uuidString
        state.markMessageAsSent(id: id)
        DebugLogger.log("📤 本地添加消息 (Local Echo) - ID: \(id), text: \(text.prefix(30))", level: .debug)
        state.appendMessage(ChatMessage(id: id, channel: state.currentChannel, sender: state.myNick, text: text, isLocalEcho: true))
        send(json: ["type": "message", "id": id, "room": state.currentChannel, "text": text])
    }
    
    func sendAttachment(_ attachment: Attachment) {
        let msgId = UUID().uuidString
        state.markMessageAsSent(id: msgId)
        state.appendMessage(ChatMessage(id: msgId, channel: state.currentChannel, sender: state.myNick, text: "", attachments: [attachment], isLocalEcho: true))
        send(json: [
            "id": msgId,
            "channel": state.currentChannel,
            "nick": state.myNick,
            "attachment": [
                "id": attachment.id,
                "kind": attachment.kind.rawValue,
                "filename": attachment.filename,
                "url": attachment.getUrl?.absoluteString ?? ""
            ]
        ])
    }
    
    /// 修改昵称（用于 UI 调用，会同步到服务器）
    func changeNick(_ newNick: String) {
        let trimmedNick = newNick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNick.isEmpty else { return }
        
        let isFirstTimeSetup = state.myNick == "iOSUser" || state.myNick.hasPrefix("iOSUser")
        state.myNick = trimmedNick
        send(json: ["type": "nick", "nick": trimmedNick])
        DebugLogger.log("👤 修改昵称: \(trimmedNick)", level: .websocket)
        
        // 首次设置昵称时显示进入频道的提示
        if isFirstTimeSetup {
            state.systemMessage("\(trimmedNick) 进入 #\(state.currentChannel)")
        }
    }
    
    // MARK: - 私有方法
    
    private func send(json: [String: Any]) {
        guard let ws = webSocket else {
            DebugLogger.log("⚠️ WebSocket 未连接，跳过发送", level: .warning)
            return
        }
        
        // 检查连接状态
        if ws.state != .running {
            DebugLogger.log("⚠️ WebSocket 未就绪 (state: \(ws.state.rawValue))，跳过发送", level: .warning)
            return
        }
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        
        // 记录发送的消息
        if let jsonString = String(data: data, encoding: .utf8) {
            let isEncrypted = (json["text"] as? String)?.hasPrefix("E2EE:") ?? false
            let displayMsg = isEncrypted ? "[加密消息]" : jsonString
            DebugLogger.logWebSocket(direction: "发送", message: displayMsg, encrypted: isEncrypted)
        }
        
        ws.send(.data(data)) { error in
            if let e = error {
                // TLS 错误或连接断开时，只记录调试日志
                if e.localizedDescription.contains("TLS") ||
                   e.localizedDescription.contains("cancelled") ||
                   e.localizedDescription.contains("closed") {
                    DebugLogger.log("🔌 WebSocket 已断开，发送失败（正常）", level: .debug)
                } else {
                    DebugLogger.log("❌ WebSocket 发送失败: \(e.localizedDescription)", level: .error)
                }
            }
        }
    }
    
    private func listen() {
        guard let ws = webSocket else { return }
        ws.receive { [weak self] result in
            guard let self else { return }
            
            var shouldContinue = true
            
            switch result {
            case .failure(let e):
                DebugLogger.log("❌ WebSocket 接收失败: \(e.localizedDescription)", level: .error)
                // TLS 错误或连接断开，停止监听
                if e.localizedDescription.contains("TLS") ||
                   e.localizedDescription.contains("closed") ||
                   e.localizedDescription.contains("cancelled") {
                    DebugLogger.log("🔌 WebSocket 连接已断开，停止监听", level: .warning)
                    shouldContinue = false
                    Task { @MainActor in
                        self.webSocket = nil
                    }
                }
            case .success(let msg):
                switch msg {
                case .data(let d):
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.messageHandler.handle(data: d)
                    }
                case .string(let s):
                    if let d = s.data(using: .utf8) {
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            await self.messageHandler.handle(data: d)
                        }
                    }
                @unknown default: break
                }
            }
            
            // 递归调用继续监听
            if shouldContinue {
                Task { @MainActor [weak self] in
                    self?.listen()
                }
            }
        }
    }
}
