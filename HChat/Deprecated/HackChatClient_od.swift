////
////  HackChatClient.swift
////  HChat
////
////  Created by Ryan Liu on 2025/10/21.
////
//
//import Foundation
//import Combine
//
//@MainActor
//final class HackChatClient: NSObject, ObservableObject {
//    // —— 连接 & 会话状态
//    @Published var serverURLString: String
//    @Published var currentChannel: Channel
//    @Published var nickname: String
//    @Published var connectionState: ConnectionState = .disconnected
//    @Published var messages: [ChatMessage] = []
//    @Published var channels: [Channel] = []  // 侧栏/顶部切换
//    @Published var mentionNotificationEnabled: Bool = true
//    @Published var isEndToEndEncryptionEnabled: Bool = true
//    @Published var passphraseForEndToEndEncryption: String = ""
//    @Published var searchText: String = ""
//    @Published var showOnlyMentions: Bool = false
//
//    // —— 去重：本地消息 ID 映射
//    private let clientInstanceId = UUID().uuidString
//    private var pendingByLocalId: [String: UUID] = [:]
//
//    // —— 传输
//    private var urlSession: URLSession!
//    private var webSocketTask: URLSessionWebSocketTask?
//    private var pingTimer: Timer?
//    private var encryptor: GroupPassphraseEncryptor?
//
//    init(serverURLString: String, defaultChannelName: String, nickname: String) {
//        self.serverURLString = serverURLString
//        self.currentChannel = Channel(name: defaultChannelName, kind: .publicRoom, displayName: "#\(defaultChannelName)")
//        self.nickname = nickname
//        super.init()
//        self.urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
//        self.channels = [currentChannel]
//        Notify.requestAuth()
//        // 从 nick 自动抽取 #口令
//        applyNickSideEffectsIfAny()
//    }
//
//    // MARK: - 连接
//
//    func connect() {
//        guard connectionState == .disconnected else { return }
//        guard let url = URL(string: serverURLString) else { appendSystem("无效服务器：\(serverURLString)"); return }
//        connectionState = .connecting
//        rebuildEncryptor()
//        let task = urlSession.webSocketTask(with: url)
//        webSocketTask = task; task.resume()
//        sendRaw(["cmd": "join", "channel": currentChannel.name, "nick": nickname])
//        startReceiveLoop(); startPing()
//        connectionState = .connected
//        appendSystem("已连接 \(serverURLString) 频道 \(currentChannel.displayName)")
//    }
//
//    func disconnect() {
//        pingTimer?.invalidate(); pingTimer = nil
//        webSocketTask?.cancel(with: .goingAway, reason: nil)
//        webSocketTask = nil
//        connectionState = .disconnected
//        appendSystem("已断开连接")
//    }
//
//    func switchChannel(to channel: Channel) {
//        currentChannel = channel
//        if !channels.contains(channel) { channels.append(channel) }
//        if connectionState == .connected {
//            sendRaw(["cmd": "join", "channel": currentChannel.name, "nick": nickname])
//            rebuildEncryptor()
//            appendSystem("已切换至 \(channel.displayName)")
//        }
//        messages.removeAll()
//    }
//
//    func startDirectMessage(with peerNick: String) {
//        let dm = Channel.direct(between: nickname, and: peerNick)
//        switchChannel(to: dm)
//    }
//
//    private func rebuildEncryptor() {
//        encryptor = isEndToEndEncryptionEnabled ? .makeFrom(passphrase: passphraseForEndToEndEncryption, channelName: currentChannel.name) : nil
//    }
//
//    private func applyNickSideEffectsIfAny() {
//        if let idx = nickname.firstIndex(of: "#") {
//            let base = String(nickname[..<idx])
//            let secret = String(nickname[nickname.index(after: idx)...])
//            nickname = base + "#" + secret
//            if !secret.isEmpty {
//                passphraseForEndToEndEncryption = secret
//                isEndToEndEncryptionEnabled = true
//                rebuildEncryptor()
//            }
//        }
//    }
//
//    // MARK: - 发送（含命令）
//
//    func sendChat(userInput: String) {
//        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmed.isEmpty else { return }
//
//        // 客户端命令
//        if trimmed == "/clear" { messages.removeAll(); appendSystem("（已清屏）"); return }
//        if trimmed == "/help" {
//            appendSystem("""
//            命令：
//            /join <channel>        切换/创建频道
//            /nick <name[#pass]>    修改昵称（#后自动作为群口令）
//            /dm <nick>             私聊（创建 dm.<a>.<b> 频道）
//            /me <action>           动作消息
//            /clear                 清屏
//            /help                  帮助
//            """); return
//        }
//        if trimmed.hasPrefix("/join ") {
//            let ch = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
//            guard !ch.isEmpty else { return }
//            switchChannel(to: Channel(name: ch, kind: .publicRoom, displayName: "#\(ch)"))
//            return
//        }
//        if trimmed.hasPrefix("/dm ") {
//            let peer = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)
//            guard !peer.isEmpty else { return }
//            startDirectMessage(with: peer)
//            return
//        }
//        if trimmed.hasPrefix("/nick ") {
//            let newNick = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
//            guard !newNick.isEmpty else { return }
//            nickname = newNick
//            applyNickSideEffectsIfAny()
//            appendSystem("昵称改为 \(nickname)")
//            if connectionState == .connected {
//                sendRaw(["cmd": "join", "channel": currentChannel.name, "nick": nickname])
//            }
//            return
//        }
//
//        guard connectionState == .connected else { appendSystem("尚未连接"); return }
//
//        // 文本/E2EE
//        let outbound: String
//        if let enc = encryptor { outbound = (try? enc.encryptForTransport(plaintext: trimmed)) ?? trimmed }
//        else { outbound = trimmed }
//
//        // ✅ 去重方案：发送时附带 clientId + localId；本地插一条“待确认”占位，收到服务器回显时匹配替换
//        let localId = UUID().uuidString
//        var packet: [String: Any] = ["cmd": "chat", "text": outbound, "clientId": clientInstanceId, "localId": localId]
//        sendRaw(packet)
//
//        // 本地占位（避免双条）：待服务器回显再“确认”
//        let kind: MessageKind = trimmed.hasPrefix("/me ") ? .action : .normal
//        let provisional = ChatMessage(id: UUID(), senderNickname: nickname, plaintext: trimmed, isFromSelf: true, kind: kind, attachment: nil, isProvisional: true)
//        pendingByLocalId[localId] = provisional.id
//        messages.append(provisional)
//    }
//
//    func sendAttachment(meta: AttachmentMeta) {
//        guard connectionState == .connected else { appendSystem("尚未连接"); return }
//        let payload = [
//            "type": "attachment", "mime": meta.mime, "kind": meta.kind.rawValue,
//            "url": meta.url.absoluteString, "fileName": meta.fileName ?? "", "bytes": meta.bytes ?? 0,
//            "thumbURL": meta.thumbURL?.absoluteString ?? ""
//        ] as [String : Any]
//        let json = String(decoding: try! JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
//        let text = "ATTACH:" + json
//        let outbound = (try? encryptor?.encryptForTransport(plaintext: text)) ?? text
//
//        let localId = UUID().uuidString
//        sendRaw(["cmd": "chat", "text": outbound, "clientId": clientInstanceId, "localId": localId])
//
//        let msg = ChatMessage(senderNickname: nickname, plaintext: text, isFromSelf: true, kind: .attachment, attachment: meta, isProvisional: true)
//        pendingByLocalId[localId] = msg.id
//        messages.append(msg)
//    }
//
//    private func sendRaw(_ json: [String: Any]) {
//        guard let task = webSocketTask else { return }
//        if let data = try? JSONSerialization.data(withJSONObject: json) {
//            task.send(.string(String(decoding: data, as: UTF8.self))) { [weak self] err in
//                if let e = err { self?.appendSystem("发送失败：\(e.localizedDescription)") }
//            }
//        }
//    }
//
//    // MARK: - 接收（匹配本地回显以去重；通知/震动/声音）
//
//    private func startReceiveLoop() {
//        webSocketTask?.receive { [weak self] result in
//            guard let self else { return }
//            switch result {
//            case .success(let msg): self.handleIncoming(msg)
//            case .failure(let e): self.appendSystem("连接错误：\(e.localizedDescription)"); self.disconnect(); return
//            }
//            self.startReceiveLoop()
//        }
//    }
//
//    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) {
//        guard case .string(let text) = message,
//              let data = text.data(using: .utf8),
//              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//              let cmd = obj["cmd"] as? String else { return }
//
//        if cmd == "chat" {
//            let nick = (obj["nick"] as? String) ?? "unknown"
//            let raw = (obj["text"] as? String) ?? ""
//            let clientId = (obj["clientId"] as? String) ?? ""
//            let localId = (obj["localId"] as? String) ?? ""
//            let dec = encryptor?.decryptFromTransportIfNeeded(text: raw) ?? raw
//
//            // ✅ 如果是自己发的且 localId 命中，替换本地占位，不新增
//            if clientId == clientInstanceId, let pid = pendingByLocalId.removeValue(forKey: localId),
//               let idx = messages.firstIndex(where: { $0.id == pid }) {
//                messages[idx] = ChatMessage(id: pid, senderNickname: nick, plaintext: dec, isFromSelf: true,
//                                            timestamp: Date(), kind: dec.hasPrefix("ATTACH:") ? .attachment : (dec.hasPrefix("/me ") ? .action : .normal),
//                                            attachment: parseAttachmentIfAny(dec), isProvisional: false)
//                return
//            }
//
//            // 附件解析
//            let att = parseAttachmentIfAny(dec)
//            let kind: MessageKind = att != nil ? .attachment : (dec.hasPrefix("/me ") ? .action : .normal)
//            let msg = ChatMessage(senderNickname: nick, plaintext: dec, isFromSelf: nick.hcBaseNick == nickname.hcBaseNick, kind: kind, attachment: att)
//            messages.append(msg)
//
//            // 通知 & 触感
//            if mentionNotificationEnabled, !msg.isFromSelf {
//                if dec.localizedCaseInsensitiveContains("@\(nickname.hcBaseNick)") || currentChannel.kind == .direct {
//                    Notify.fire(title: "\(nick.hcBaseNick) 提到了你", body: dec)
//                    Notify.hapticTap()
//                }
//            }
//        } else if cmd == "info" || cmd == "warn" {
//            appendSystem(obj["text"] as? String ?? "")
//        }
//    }
//
//    private func parseAttachmentIfAny(_ decrypted: String) -> AttachmentMeta? {
//        guard decrypted.hasPrefix("ATTACH:"),
//              let data = decrypted.dropFirst("ATTACH:".count).data(using: .utf8),
//              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//              let kindRaw = o["kind"] as? String,
//              let urlStr = o["url"] as? String,
//              let url = URL(string: urlStr),
//              let mime = o["mime"] as? String else { return nil }
//        return AttachmentMeta(kind: .init(rawValue: kindRaw) ?? .file,
//                              url: url, mime: mime,
//                              fileName: (o["fileName"] as? String),
//                              bytes: (o["bytes"] as? NSNumber)?.int64Value,
//                              thumbURL: (o["thumbURL"] as? String).flatMap(URL.init(string:)))
//    }
//
//    private func startPing() {
//        pingTimer?.invalidate()
//        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
//            self?.webSocketTask?.sendPing { if let e = $0 { print("Ping failed:", e) } }
//        }
//    }
//
//    private func appendSystem(_ t: String) {
//        messages.append(ChatMessage(senderNickname: "system", plaintext: t, isFromSelf: false, kind: .system, attachment: nil))
//    }
//}
