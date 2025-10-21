//
//  HackChatClient.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import Observation

@MainActor
@Observable
final class HackChatClient {
    var channels: [Channel] = [Channel(name: "lobby")]
    var currentChannel: String = "lobby"
    var messagesByChannel: [String: [ChatMessage]] = [:]
    var myNick: String = "iOSUser"
    var passphraseForEndToEndEncryption: String = ""  // 群口令
    var onlineByRoom: [String: Set<String>] = [:]
    var onlineCountByRoom: [String: Int] = [:]

    private var webSocket: URLSessionWebSocketTask?
    private var sentMessageIds = Set<String>() // ✅ 去重关键（防自己重复 append）

    
    // MARK: - Connect
    func connect(to url: URL) {
        DebugLogger.log("🔌 连接 WebSocket: \(url.absoluteString)", level: .websocket)
        
        let task = URLSession.shared.webSocketTask(with: url)
        self.webSocket = task
        task.resume()

        // ✅ 发送 nick / join
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            DebugLogger.log("👤 设置昵称: \(myNick)", level: .websocket)
            send(json: ["type":"nick","nick": myNick])
            DebugLogger.log("🚪 加入频道: \(currentChannel)", level: .websocket)
            send(json: ["type":"join","room": currentChannel])
            // 立刻要一次在线 / 每 20s 拉一次
            send(json: ["type":"who","room": currentChannel])
        }

        // 周期性 who（保持在线列表刷新）
        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.send(json: ["type":"who","room": self.currentChannel])
        }

        listen()
    }

    func disconnect() {
        DebugLogger.log("🔌 断开 WebSocket 连接", level: .websocket)
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    // MARK: - Send
    func sendText(_ text: String) {
        if let cmd = CommandParser.parse(text) { handleCommand(cmd); return }
        let id = UUID().uuidString
        sentMessageIds.insert(id)
        DebugLogger.log("📤 本地添加消息 (Local Echo) - ID: \(id), text: \(text.prefix(30))", level: .debug)
        appendMessage(ChatMessage(id: id, channel: currentChannel, sender: myNick, text: text, isLocalEcho: true))
        send(json: ["type":"message","id": id, "room": currentChannel, "text": text])
    }

    func sendAttachment(_ attachment: Attachment) {
        let msgId = UUID().uuidString
        sentMessageIds.insert(msgId)
        appendMessage(ChatMessage(id: msgId, channel: currentChannel, sender: myNick, text: "", attachments: [attachment], isLocalEcho: true))
        send(json: [
            "id": msgId,
            "channel": currentChannel,
            "nick": myNick,
            "attachment": [
                "id": attachment.id,
                "kind": attachment.kind.rawValue,
                "filename": attachment.filename,
                "url": attachment.getUrl?.absoluteString ?? ""
            ]
        ])
    }

    private func send(json: [String: Any]) {
        guard let ws = webSocket else { return }
        let data = try! JSONSerialization.data(withJSONObject: json)
        
        // 记录发送的消息（隐藏密文内容，只显示类型）
        if let jsonString = String(data: data, encoding: .utf8) {
            let isEncrypted = (json["text"] as? String)?.hasPrefix("E2EE:") ?? false
            let displayMsg = isEncrypted ? "[加密消息]" : jsonString
            DebugLogger.logWebSocket(direction: "发送", message: displayMsg, encrypted: isEncrypted)
        }
        
        ws.send(.data(data)) { error in
            if let e = error { 
                DebugLogger.log("❌ WebSocket 发送失败: \(e.localizedDescription)", level: .error)
            }
        }
    }
    func sendDM(to nick: String, text: String) {
        let id = UUID().uuidString
        sentMessageIds.insert(id)
        // 归入一个“pm/\(nick)”的本地会话
        let ch = "pm/\(nick)"
        appendMessage(ChatMessage(id: id, channel: ch, sender: myNick, text: text, isLocalEcho: true))
        send(json: ["type":"dm","id": id, "to": nick, "text": text])
    }

    // MARK: - Receive
    private func listen() {
        guard let ws = webSocket else { return }
        ws.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let e):
                print("ws receive error:", e.localizedDescription)
            case .success(let msg):
                switch msg {
                case .data(let d): 
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.handleIncomingData(d)
                    }
                case .string(let s): 
                    if let d = s.data(using: .utf8) { 
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            await self.handleIncomingData(d)
                        }
                    }
                @unknown default: break
                }
            }
            Task { @MainActor [weak self] in
                self?.listen()
            }
        }
    }

    private func handleIncomingData(_ data: Data) async {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        // 记录接收的消息
        if let jsonString = String(data: data, encoding: .utf8) {
            let isEncrypted = (obj["text"] as? String)?.hasPrefix("E2EE:") ?? false
            let displayMsg = isEncrypted ? "[加密消息 from \(obj["nick"] ?? "unknown")]" : jsonString
            DebugLogger.logWebSocket(direction: "接收", message: displayMsg, encrypted: isEncrypted)
        }
        
        let type = (obj["type"] as? String) ?? "message"

        if type == "presence" {
            let room = (obj["room"] as? String) ?? currentChannel
            let users = (obj["users"] as? [String]) ?? []
            onlineByRoom[room] = Set(users)

            if let count = obj["count"] as? Int {
                onlineCountByRoom[room] = count    // 优先用连接总数
            } else {
                onlineCountByRoom[room] = users.count
            }
            return
        }
        
        // 处理昵称变更通知
        if type == "nick_change" {
            let oldNick = (obj["oldNick"] as? String) ?? ""
            let newNick = (obj["newNick"] as? String) ?? ""
            let channel = (obj["channel"] as? String) ?? currentChannel
            
            DebugLogger.log("👤 昵称变更: \(oldNick) → \(newNick) (频道: \(channel))", level: .debug)
            
            // 更新该频道所有消息中的发送者昵称
            if var messages = messagesByChannel[channel] {
                for index in messages.indices {
                    if messages[index].sender == oldNick {
                        // 创建新的消息对象（因为 ChatMessage 是 struct）
                        let oldMsg = messages[index]
                        messages[index] = ChatMessage(
                            id: oldMsg.id,
                            channel: oldMsg.channel,
                            sender: newNick,  // 更新昵称
                            text: oldMsg.text,
                            timestamp: oldMsg.timestamp,
                            attachments: oldMsg.attachments,
                            isLocalEcho: oldMsg.isLocalEcho
                        )
                    }
                }
                messagesByChannel[channel] = messages
            }
            
            // 显示系统提示
            systemMessage("\(oldNick) 更名为 \(newNick)")
            return
        }

        if type == "dm" {
            let msgId = (obj["id"] as? String) ?? UUID().uuidString
            if sentMessageIds.contains(msgId) { sentMessageIds.remove(msgId); return }
            let from = (obj["from"] as? String) ?? "unknown"
            let to = (obj["to"] as? String) ?? ""
            let text = (obj["text"] as? String) ?? ""
            let ch = "pm/" + ((from == myNick) ? to : from) // 归入同一个会话
            appendMessage(ChatMessage(id: msgId, channel: ch, sender: from, text: text))
            return
        }
        // 兼容服务端字段
        let msgId = (obj["id"] as? String) ?? UUID().uuidString
        let channel = (obj["channel"] as? String) ?? currentChannel
        let nick = (obj["nick"] as? String) ?? "server"
        let text = (obj["text"] as? String) ?? ""
        
        DebugLogger.log("📥 收到消息 - ID: \(msgId), nick: \(nick), text: \(text.prefix(30))", level: .debug)
        
        var attachments: [Attachment] = []
        if let a = obj["attachment"] as? [String: Any],
           let urlStr = a["url"] as? String,
           let u = URL(string: urlStr) {
            let kind = Attachment.Kind(rawValue: (a["kind"] as? String) ?? "file") ?? .file
            let fn = (a["filename"] as? String) ?? "attachment"
            attachments = [Attachment(kind: kind, filename: fn, contentType: "application/octet-stream", putUrl: nil, getUrl: u, sizeBytes: nil)]
        }

        // ✅ 去重策略：若是自己刚发的 msgId，则不再追加（避免"双发"）
        if sentMessageIds.contains(msgId) {
            DebugLogger.log("✅ 去重成功 - 忽略自己发送的消息 ID: \(msgId)", level: .debug)
            sentMessageIds.remove(msgId)
            return
        }
        
        DebugLogger.log("📝 添加消息到列表 - ID: \(msgId), from: \(nick)", level: .debug)
        let message = ChatMessage(id: msgId, channel: channel, sender: nick, text: text, attachments: attachments)
        appendMessage(message)

        // @ 提及通知
        if text.contains("@\(myNick)") {
            NotificationManager.shared.notifyMention(channel: channel, from: nick, text: text)
        }
    }

    // MARK: - Commands
    private func handleCommand(_ cmd: ClientCommand) {
        switch cmd {
        case .join(let room):
            if channels.contains(where: { $0.name == room }) == false {
                channels.append(Channel(name: room))
            }
            currentChannel = room
            systemMessage("已加入 #\(room)")

        case .nick(let name):
            myNick = name
            if let pass = CommandParser.extractPassphrase(fromNick: name) {
                passphraseForEndToEndEncryption = pass
                systemMessage("E2EE 群口令已更新")
            } else {
                systemMessage("昵称已更新为 \(name)")
            }
                
        case .dm(let to, let text):
            sendDM(to: to, text: text)

        case .me(let action):
            let m = ChatMessage(channel: currentChannel, sender: myNick, text: "/me \(action)")
            appendMessage(m)
            send(json: ["channel": currentChannel, "nick": myNick, "text": "/me \(action)"])

        case .clear:
            messagesByChannel[currentChannel] = []
        case .help:
            systemMessage("支持命令：/join /nick /me /clear /help")
        case .unknown(let raw):
            systemMessage("未知命令：\(raw)")
        }
    }

    private func systemMessage(_ text: String) {
        appendMessage(ChatMessage(channel: currentChannel, sender: "system", text: text))
    }

    private func appendMessage(_ m: ChatMessage) {
        DebugLogger.log("➕ appendMessage - ID: \(m.id), channel: \(m.channel), sender: \(m.sender), isLocalEcho: \(m.isLocalEcho)", level: .debug)
        var arr = messagesByChannel[m.channel, default: []]
        arr.append(m)
        messagesByChannel[m.channel] = arr
        if let idx = channels.firstIndex(where: { $0.name == m.channel }) {
            channels[idx].lastMessageAt = m.timestamp
            if m.channel != currentChannel { channels[idx].unreadCount += 1 }
        }
    }
}
