import SwiftUI
import UserNotifications

@main
struct HChatApp: App {
    @State var client = HackChatClient()

    var body: some Scene {
        WindowGroup {
            ChatView(client: client)
                .onAppear {
                    // ✅ 请求通知权限
                    Task {
                        await SmartNotificationManager.shared.requestPermission()
                    }
                    
                    // 连接你的 chat-gateway WebSocket
                    if let url = URL(string: "wss://hc.go-lv.com/chat-ws") {
                        client.connect(to: url)
                    }
                }
        }
    }
}







//import SwiftUI
//import Combine
//import CryptoKit
//import PhotosUI
//import AVKit
//import UserNotifications
//import UniformTypeIdentifiers   // ✅ 新增：使用 UTType 需要它
//
//// MARK: - 模型
//
//enum ConnectionState: String { case disconnected, connecting, connected }
//enum MessageKind { case normal, action, system, attachment }
//
//struct AttachmentMeta: Codable, Equatable {
//    enum Kind: String, Codable { case image, video, audio, file }
//    let kind: Kind
//    let url: URL                  // 直链（minio 预签名上传后，用 getUrl）
//    let mime: String
//    let fileName: String?
//    let bytes: Int64?
//}
//
//struct ChatMessage: Identifiable, Equatable {
//    let id = UUID()
//    let senderNickname: String
//    let rawTextFromServer: String       // 原始（可能是 E2EE 包装）
//    let plaintext: String               // 解密或直传后的明文（若是 ATTACH: 则为 "ATTACH:{json}"）
//    let isFromSelf: Bool
//    let timestamp: Date
//    let kind: MessageKind
//    let attachment: AttachmentMeta?
//}
//
//// MARK: - 主题 & 小工具
//
//enum HackTheme {
//    static let background = Color(hue: 0.62, saturation: 0.05, brightness: 0.08)
//    static let panel = Color(hue: 0.62, saturation: 0.10, brightness: 0.13)
//    static let panelStroke = Color.white.opacity(0.06)
//    static let myBubble = Color.accentColor.opacity(0.18)
//    static let otherBubble = Color.white.opacity(0.06)
//    static let systemText = Color.secondary
//    static let monospacedBody = Font.system(.body, design: .monospaced)
//}
//
//extension String {
//    var hcBaseNick: String { self.split(separator: "#").first.map(String.init) ?? self }
//}
//
//func colorForNickname(_ nick: String) -> Color {
//    let h = Double(abs(nick.hcBaseNick.hashValue % 360)) / 360.0
//    return Color(hue: h, saturation: 0.55, brightness: 0.85)
//}
//
//// MARK: - E2EE（与之前相同）
//private func ymdPathString(_ date: Date = Date()) -> String {
//    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
//    return String(format: "%04d/%02d/%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
//}
//
//
//struct GroupPassphraseEncryptor {
//    let symmetricKey: SymmetricKey
//
//    static func makeFrom(passphrase: String, channelName: String, iterations: Int = 250_000) -> GroupPassphraseEncryptor {
//        let salt = Data(("hc:" + channelName).utf8)
//        let keyData = PBKDF2_HMAC_SHA256(password: Data(passphrase.utf8),
//                                         salt: salt,
//                                         iterations: iterations,
//                                         derivedKeyLength: 32)
//        return GroupPassphraseEncryptor(symmetricKey: SymmetricKey(data: keyData))
//    }
//
//    func encryptForTransport(plaintext: String) throws -> String {
//        let nonce = AES.GCM.Nonce()
//        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: symmetricKey, nonce: nonce)
//        let combined = sealed.ciphertext + sealed.tag
//        let env: [String: Any] = ["v": 1, "alg": "AES-GCM",
//                                  "iv": Data(nonce).base64EncodedString(),
//                                  "ct": combined.base64EncodedString()]
//        let json = try JSONSerialization.data(withJSONObject: env)
//        return "E2EE:" + json.base64EncodedString()
//    }
//
//    func decryptFromTransportIfNeeded(text: String) -> String {
//        guard text.hasPrefix("E2EE:") else { return text }
//        do {
//            let b64 = String(text.dropFirst(5))
//            guard let data = Data(base64Encoded: b64),
//                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//                  let ivB64 = obj["iv"] as? String,
//                  let ctB64 = obj["ct"] as? String,
//                  let ivData = Data(base64Encoded: ivB64),
//                  let cipherPlusTag = Data(base64Encoded: ctB64) else { return "（解密失败：格式错误）" }
//            guard cipherPlusTag.count >= 16 else { return "（解密失败：密文过短）" }
//            let tag = cipherPlusTag.suffix(16)
//            let cipher = cipherPlusTag.prefix(cipherPlusTag.count - 16)
//            let sealed = try AES.GCM.SealedBox(nonce: .init(data: ivData), ciphertext: cipher, tag: tag)
//            let plain = try AES.GCM.open(sealed, using: symmetricKey)
//            return String(decoding: plain, as: UTF8.self)
//        } catch { return "（解密失败：\(error.localizedDescription)）" }
//    }
//
//    private static func PBKDF2_HMAC_SHA256(password: Data, salt: Data, iterations: Int, derivedKeyLength: Int) -> Data {
//        func INT(_ i: UInt32) -> Data { withUnsafeBytes(of: i.bigEndian) { Data($0) } }
//        func hmac(_ key: Data, _ msg: Data) -> Data {
//            let sk = SymmetricKey(data: key)
//            return Data(HMAC<SHA256>.authenticationCode(for: msg, using: sk))
//        }
//        var out = Data(); var block: UInt32 = 1
//        while out.count < derivedKeyLength {
//            let u1 = hmac(password, salt + INT(block)); var t = u1
//            if iterations > 1 {
//                var up = u1
//                for _ in 2...iterations {
//                    let u = hmac(password, up)
//                    t = Data(zip(t, u).map(^))
//                    up = u
//                }
//            }
//            out.append(t); block += 1
//        }
//        return out.prefix(derivedKeyLength)
//    }
//}
//
//// MARK: - 富文本（@、链接、行内/块代码）
//
//struct RichMessageText: View {
//    let message: ChatMessage
//    let myBaseNick: String
//
//    var body: some View {
//        if let att = message.attachment {
//            AttachmentCardView(attachment: att)
//        } else {
//            let attr = buildAttributedText(message: message, myBaseNick: myBaseNick)
//            Text(attr)
//                .font(HackTheme.monospacedBody)
//                .textSelection(.enabled)
//        }
//    }
//
//    private func buildAttributedText(message: ChatMessage, myBaseNick: String) -> AttributedString {
//        // /me -> "* nick action"
//        var text = message.plaintext
//        var isAction = false
//        if text.hasPrefix("/me ") {
//            isAction = true
//            text = "* \(message.senderNickname.hcBaseNick) " + text.dropFirst(4)
//        }
//
//        // 先处理代码块 ```lang\n...\n```（简单高亮）
//        // 用占位符替换以避免与行内代码互相干扰
//        var codeBlocks: [Range<String.Index>: (lang: String?, code: String)] = [:]
//        let patternBlock = try! NSRegularExpression(pattern: "```(\\w+)?\\n([\\s\\S]*?)```", options: [])
//        let ns = text as NSString
//        var mutable = text
//        let matches = patternBlock.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed()
//        for m in matches {
//            let lang = m.range(at: 1).location != NSNotFound ? ns.substring(with: m.range(at: 1)) : nil
//            let code = ns.substring(with: m.range(at: 2))
//            if let r = Range(m.range, in: mutable) {
//                codeBlocks[r] = (lang, code)
//                mutable.replaceSubrange(r, with: "§§CODEBLOCK_PLACEHOLDER§§")
//            }
//        }
//
//        var attr = AttributedString(mutable)
//
//        // 链接识别
//        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
//            let nsM = mutable as NSString
//            detector.matches(in: mutable, range: NSRange(location: 0, length: nsM.length)).forEach { m in
//                if let url = m.url, let range = Range(m.range, in: attr) {
//                    attr[range].foregroundColor = .cyan
//                    attr[range].underlineStyle = .single
//                    attr[range].link = url
//                }
//            }
//        }
//
//        // 行内代码 `...`
//        let inline = try! NSRegularExpression(pattern: "`([^`]+)`")
//        let nsI = mutable as NSString
//        inline.matches(in: mutable, range: NSRange(location: 0, length: nsI.length)).forEach { m in
//            if let range = Range(m.range(at: 1), in: attr) {
//                attr[range].font = .system(size: UIFont.labelFontSize, weight: .regular).monospaced()
//                attr[range].backgroundColor = UIColor.black.withAlphaComponent(0.25)
//                attr[range].foregroundColor = .white
//            }
//        }
//
//        // @ 提及（忽略大小写）
//        let mention = "@\(myBaseNick)"
//        if !myBaseNick.isEmpty, let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: mention), options: [.caseInsensitive]) {
//            let nsM = mutable as NSString
//            regex.matches(in: mutable, range: NSRange(location: 0, length: nsM.length)).forEach { m in
//                if let r = Range(m.range, in: attr) {
//                    attr[r].backgroundColor = UIColor.yellow.withAlphaComponent(0.2)
//                    attr[r].foregroundColor = .yellow
//                    attr[r].font = .system(size: UIFont.labelFontSize, weight: .semibold)
//                }
//            }
//        }
//
//        // /me 样式
//        if isAction {
//            attr.font = .system(size: UIFont.labelFontSize, weight: .regular).italic()
//            attr.foregroundColor = UIColor(colorForNickname(message.senderNickname))
//        }
//
//        // 回填代码块占位符 → 粗暴替换成「[code]...[/code]」样式
//        var final = String(attr.characters)
//        while let r = final.range(of: "§§CODEBLOCK_PLACEHOLDER§§"), let originalRange = codeBlocks.keys.first(where: { _ in true }) {
//            let block = codeBlocks.removeValue(forKey: originalRange)!
//            let pretty = "\n╭─ \(block.lang ?? "code") ─────────────────\n\(block.code)\n╰─────────────────────────\n"
//            final.replaceSubrange(r, with: pretty)
//        }
//
//        var attrFinal = AttributedString(final)
//        // 对「╭─...」包裹内容整体设等宽 + 背景
//        if let rangeTop = final.range(of: "╭"), let rangeBottom = final.range(of: "╰", options: .backwards) {
//            if let r = Range(rangeTop.lowerBound..<final.index(after: rangeBottom.lowerBound), in: attrFinal) {
//                attrFinal[r].font = .system(size: UIFont.labelFontSize, weight: .regular).monospaced()
//                attrFinal[r].backgroundColor = UIColor.black.withAlphaComponent(0.2)
//            }
//        }
//
//        return attrFinal
//    }
//}
//
//// MARK: - WebSocket 客户端（命令解析 + 提及通知 + 附件发送）
//
//@MainActor
//final class HackChatClient: NSObject, ObservableObject {
//    @Published var serverURLString: String
//    @Published var channelName: String
//    @Published var nickname: String
//    @Published var connectionState: ConnectionState = .disconnected
//    @Published var messages: [ChatMessage] = []
//    @Published var isEndToEndEncryptionEnabled: Bool = true
//    @Published var passphraseForEndToEndEncryption: String = ""
//    @Published var mentionNotificationEnabled: Bool = true
//
//    // 搜索过滤
//    @Published var searchText: String = ""
//    @Published var showOnlyMentions: Bool = false
//
//    private var urlSession: URLSession!
//    private var webSocketTask: URLSessionWebSocketTask?
//    private var pingTimer: Timer?
//    private var encryptor: GroupPassphraseEncryptor?
//
//    init(serverURLString: String, channelName: String, nickname: String) {
//        self.serverURLString = serverURLString
//        self.channelName = channelName
//        self.nickname = nickname
//        super.init()
//        self.urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
//        requestNotificationPermission()
//    }
//
//    // MARK: connect / disconnect
//
//    func connect() {
//        guard connectionState == .disconnected else { return }
//        guard let url = URL(string: serverURLString) else {
//            appendSystem("无效的服务器地址：\(serverURLString)"); return
//        }
//        connectionState = .connecting
//        encryptor = isEndToEndEncryptionEnabled ? .makeFrom(passphrase: passphraseForEndToEndEncryption, channelName: channelName) : nil
//        let task = urlSession.webSocketTask(with: url)
//        webSocketTask = task
//        task.resume()
//        sendRaw(json: ["cmd": "join", "channel": channelName, "nick": nickname])
//        startReceiveLoop(); startPing()
//        connectionState = .connected
//        appendSystem("已连接 \(serverURLString) 频道 #\(channelName)")
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
//    // MARK: 发送（含命令解析）
//
//    func sendChat(text: String) {
//        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmed.isEmpty else { return }
//
//        // 客户端命令
//        if trimmed == "/clear" { messages.removeAll(); appendSystem("（已清屏）"); return }
//        if trimmed == "/help" {
//            appendSystem("""
//            可用命令：
//            /join <channel>      切换频道并重连
//            /nick <name[#pass]>  修改昵称（可包含 #groupkey）
//            /me <action>         以动作形式发言
//            /clear               清屏
//            /help                帮助
//            """); return
//        }
//        if trimmed.hasPrefix("/join ") {
//            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
//            if parts.count == 2 {
//                channelName = parts[1]
//                appendSystem("切换到 #\(channelName)，正在重连…")
//                disconnect(); connect()
//            }
//            return
//        }
//        if trimmed.hasPrefix("/nick ") {
//            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
//            if parts.count == 2 {
//                nickname = parts[1]
//                appendSystem("昵称改为 \(nickname)")
//                // 通知服务器（hack.chat 语义通常本地即生效，网关无状态）
//                sendRaw(json: ["cmd": "join", "channel": channelName, "nick": nickname])
//            }
//            return
//        }
//
//        guard connectionState == .connected else { appendSystem("尚未连接"); return }
//
//        // /me 与普通消息一样发送（兼容性最好），渲染时做样式
//        let transportText: String
//        if let enc = encryptor {
//            transportText = (try? enc.encryptForTransport(plaintext: trimmed)) ?? trimmed
//        } else {
//            transportText = trimmed
//        }
//        sendRaw(json: ["cmd": "chat", "text": transportText])
//
//        let kind: MessageKind = trimmed.hasPrefix("/me ") ? .action : .normal
//        messages.append(ChatMessage(senderNickname: nickname,
//                                    rawTextFromServer: transportText,
//                                    plaintext: trimmed,
//                                    isFromSelf: true,
//                                    timestamp: Date(),
//                                    kind: kind,
//                                    attachment: nil))
//    }
//
//    // 发送附件（会在聊天中插入一条 ATTACH 消息）
//    func sendAttachment(meta: AttachmentMeta) {
//        guard connectionState == .connected else { appendSystem("尚未连接"); return }
//        let payload: [String: Any] = [
//            "type": "attachment",
//            "mime": meta.mime,
//            "kind": meta.kind.rawValue,
//            "url": meta.url.absoluteString,
//            "fileName": meta.fileName ?? "",
//            "bytes": meta.bytes ?? 0
//        ]
//        let data = try! JSONSerialization.data(withJSONObject: payload)
//        let text = "ATTACH:" + String(decoding: data, as: UTF8.self)
//
//        let transportText = (try? encryptor?.encryptForTransport(plaintext: text)) ?? text
//        sendRaw(json: ["cmd": "chat", "text": transportText])
//
//        messages.append(ChatMessage(senderNickname: nickname,
//                                    rawTextFromServer: transportText,
//                                    plaintext: text,
//                                    isFromSelf: true,
//                                    timestamp: Date(),
//                                    kind: .attachment,
//                                    attachment: meta))
//    }
//
//    private func sendRaw(json: [String: Any]) {
//        guard let task = webSocketTask else { return }
//        if let data = try? JSONSerialization.data(withJSONObject: json) {
//            task.send(.string(String(decoding: data, as: UTF8.self))) { [weak self] error in
//                if let error { self?.appendSystem("发送失败：\(error.localizedDescription)") }
//            }
//        }
//    }
//
//    // MARK: 接收（提及通知 + ATTACH 解析）
//
//    private func startReceiveLoop() {
//        webSocketTask?.receive { [weak self] result in
//            guard let self else { return }
//            switch result {
//            case .success(let message): self.handleIncoming(message)
//            case .failure(let e):
//                self.appendSystem("连接错误：\(e.localizedDescription)")
//                self.disconnect(); return
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
//            let decrypted = encryptor?.decryptFromTransportIfNeeded(text: raw) ?? raw
//
//            // ATTACH
//            if decrypted.hasPrefix("ATTACH:"),
//               let json = decrypted.dropFirst("ATTACH:".count).data(using: .utf8),
//               let payload = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
//               let kindRaw = payload["kind"] as? String,
//               let urlStr = payload["url"] as? String,
//               let url = URL(string: urlStr),
//               let mime = payload["mime"] as? String {
//                let meta = AttachmentMeta(kind: .init(rawValue: kindRaw) ?? .file,
//                                          url: url,
//                                          mime: mime,
//                                          fileName: payload["fileName"] as? String,
//                                          bytes: (payload["bytes"] as? NSNumber)?.int64Value)
//                messages.append(ChatMessage(senderNickname: nick,
//                                            rawTextFromServer: raw,
//                                            plaintext: decrypted,
//                                            isFromSelf: nick.hcBaseNick == nickname.hcBaseNick,
//                                            timestamp: Date(),
//                                            kind: .attachment,
//                                            attachment: meta))
//                maybeNotifyMentionIfNeeded(text: "", from: nick) // 附件消息不做 @ 识别
//                return
//            }
//
//            // 普通/动作
//            let kind: MessageKind = decrypted.hasPrefix("/me ") ? .action : .normal
//            messages.append(ChatMessage(senderNickname: nick,
//                                        rawTextFromServer: raw,
//                                        plaintext: decrypted,
//                                        isFromSelf: nick.hcBaseNick == nickname.hcBaseNick,
//                                        timestamp: Date(),
//                                        kind: kind,
//                                        attachment: nil))
//            maybeNotifyMentionIfNeeded(text: decrypted, from: nick)
//        } else if cmd == "info" || cmd == "warn" {
//            appendSystem(obj["text"] as? String ?? "")
//        }
//    }
//
//    // MARK: ping
//
//    private func startPing() {
//        pingTimer?.invalidate()
//        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
//            self?.webSocketTask?.sendPing { if let e = $0 { print("Ping failed:", e) } }
//        }
//    }
//
//    // MARK: 本地通知
//
//    private func requestNotificationPermission() {
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
//    }
//
//    private func maybeNotifyMentionIfNeeded(text: String, from nick: String) {
//        guard mentionNotificationEnabled else { return }
//        let target = "@\(nickname.hcBaseNick)"
//        if !text.isEmpty, text.localizedCaseInsensitiveContains(target), nick.hcBaseNick != nickname.hcBaseNick {
//            let content = UNMutableNotificationContent()
//            content.title = "\(nick.hcBaseNick) 提到了你"
//            content.body = text
//            content.sound = .default
//            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString,
//                                                                         content: content, trigger: nil))
//        }
//    }
//
//    private func appendSystem(_ t: String) {
//        messages.append(ChatMessage(senderNickname: "system",
//                                    rawTextFromServer: t,
//                                    plaintext: t,
//                                    isFromSelf: false,
//                                    timestamp: Date(),
//                                    kind: .system,
//                                    attachment: nil))
//    }
//
//    // MARK: - 附件：预签名直传（MinIO）
//
//    struct PresignResponse: Decodable {
//        let bucket: String
//        let objectKey: String
//        let putUrl: String
//        let getUrl: String
//        let expiresSeconds: Int
//    }
//
//    /// 将（可选加密后的）文件上传到 S3/MinIO，返回附件元数据
//    func encryptAndUploadIfNeeded(sourceURL: URL, suggestedMime: String?, fileName: String?) async throws -> AttachmentMeta {
//        // TODO：如需 E2EE 文件加密，把 sourceURL 先过 SecretStreamFileEncryptor，得到 encryptedURL + header
//        let fileURL = sourceURL
//
//        let datePath = ymdPathString()
//        let ext = fileURL.pathExtension.isEmpty ? "bin" : fileURL.pathExtension
//        let key = "rooms/\(channelName)/\(datePath)/\(UUID().uuidString).\(ext)"
//
//
//        // 1) presign
//        var req = URLRequest(url: URL(string: "https://hc.go-lv.com/api/attachments/presign")!)
//        req.httpMethod = "POST"
//        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        let body: [String: Any] = [
//            "objectKey": key,
//            "contentType": suggestedMime ?? "application/octet-stream"
//        ]
//        req.httpBody = try JSONSerialization.data(withJSONObject: body)
//        let (data, resp) = try await URLSession.shared.data(for: req)
//        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
//        let presign = try JSONDecoder().decode(PresignResponse.self, from: data)
//
//        // 2) PUT 上传
//        var putReq = URLRequest(url: URL(string: presign.putUrl)!)
//        putReq.httpMethod = "PUT"
//        putReq.setValue(suggestedMime ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
//        let (tmpData, _) = try await URLSession.shared.upload(for: putReq, fromFile: fileURL)
//        _ = tmpData // 无需响应体
//
//        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value
//
//        // 3) 返回 meta（聊天消息会包一层 ATTACH JSON 并 E2EE）
//        let kind = kindGuess(fromMime: suggestedMime ?? "application/octet-stream")
//        return AttachmentMeta(kind: kind, url: URL(string: presign.getUrl)!, mime: suggestedMime ?? "application/octet-stream", fileName: fileName, bytes: size)
//    }
//
//    private func kindGuess(fromMime mime: String) -> AttachmentMeta.Kind {
//        if mime.hasPrefix("image/") { return .image }
//        if mime.hasPrefix("video/") { return .video }
//        if mime.hasPrefix("audio/") { return .audio }
//        return .file
//    }
//}
//
//// MARK: - 时间戳
//
//enum TimestampStyle: Int, CaseIterable {
//    case off = 0, relative, absolute
//    var title: String {
//        switch self {
//        case .off: return "时间戳：关"
//        case .relative: return "时间戳：相对"
//        case .absolute: return "时间戳：绝对"
//        }
//    }
//}
//func formattedTimestamp(_ date: Date, style: TimestampStyle) -> String? {
//    switch style {
//    case .off: return nil
//    case .relative:
//        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
//        return f.localizedString(for: date, relativeTo: Date())
//    case .absolute:
//        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
//    }
//}
//
//// MARK: - UI：附件卡片
//
//struct AttachmentCardView: View {
//    let attachment: AttachmentMeta
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            switch attachment.kind {
//            case .image:
//                AsyncImage(url: attachment.url) { phase in
//                    switch phase {
//                    case .success(let img): img.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
//                    case .failure(_): placeholder
//                    case .empty: progress
//                    @unknown default: progress
//                    }
//                }
//                .frame(maxHeight: 260)
//            case .video:
//                VideoPlayer(player: AVPlayer(url: attachment.url))
//                    .frame(height: 220)
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
//            case .audio:
//                HStack {
//                    Image(systemName: "waveform.circle").imageScale(.large)
//                    Text(attachment.fileName ?? "音频").lineLimit(1)
//                    Spacer()
//                    Link("播放", destination: attachment.url)
//                }
//            case .file:
//                HStack {
//                    Image(systemName: "doc.fill").imageScale(.large)
//                    VStack(alignment: .leading) {
//                        Text(attachment.fileName ?? "文件")
//                            .lineLimit(1)
//                        Text(attachment.mime).font(.caption2).foregroundStyle(.secondary)
//                    }
//                    Spacer()
//                    Link("打开", destination: attachment.url)
//                }
//            }
//            if let bytes = attachment.bytes {
//                Text("\(bytes) bytes").font(.caption2).foregroundStyle(.secondary)
//            }
//        }
//        .padding(10)
//        .background(HackTheme.otherBubble, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
//        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HackTheme.panelStroke))
//    }
//
//    private var placeholder: some View {
//        ZStack { RoundedRectangle(cornerRadius: 12).fill(HackTheme.otherBubble); ProgressView() }.frame(height: 220)
//    }
//    private var progress: some View { placeholder }
//}
//
//// MARK: - 视图
//
//@main
//struct HChatApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ModernChatView(viewModel: .init(
//                serverURLString: "wss://hc.go-lv.com/chat-ws",
//                channelName: "ios-dev",
//                nickname: "yourname#secret"
//            ))
//            .preferredColorScheme(.dark)
//        }
//    }
//}
//
//struct ModernChatView: View {
//    @StateObject private var viewModel: HackChatClient
//    @State private var messageDraft: String = ""
//    @FocusState private var isInputFocused: Bool
//
//    @AppStorage("timestampStyle") private var tsStyleRaw: Int = TimestampStyle.relative.rawValue
//    private var tsStyle: TimestampStyle { TimestampStyle(rawValue: tsStyleRaw) ?? .relative }
//
//    // 附件选择
//    @State private var showFileImporter = false
//    @State private var selectedPhotoItem: PhotosPickerItem?
//
//    init(viewModel: HackChatClient) { _viewModel = StateObject(wrappedValue: viewModel) }
//
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                HackTheme.background.ignoresSafeArea()
//                VStack(spacing: 0) {
//                    channelControlsCard
//                        .padding(.horizontal, 12)
//                        .padding(.top, 8)
//
//                    Divider().overlay(HackTheme.panelStroke).padding(.bottom, 6)
//
//                    chatScroll
//
//                    inputBar
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 10)
//                        .background(.ultraThinMaterial)
//                        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(HackTheme.panelStroke), alignment: .top)
//                }
//            }
//            .toolbar {
//                ToolbarItem(placement: .topBarLeading) { searchToggle }
//                ToolbarItem(placement: .topBarTrailing) { connectButton }
//                ToolbarItem(placement: .topBarTrailing) { timestampMenu }
//                ToolbarItem(placement: .topBarTrailing) { notifyToggle }
//            }
//            .navigationTitle("hack.chat")
//            .navigationBarTitleDisplayMode(.inline)
//            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索消息")
//        }
//        .tint(.mint)
//        // PhotosPicker 结果处理
//        .onChange(of: selectedPhotoItem) { _, newItem in
//            guard let item = newItem else { return }
//            Task { await handlePhotoPicked(item) }
//        }
//    }
//
//    // 顶部：频道 / 昵称 / E2EE
//    private var channelControlsCard: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack(spacing: 8) {
//                TextField("频道名（如 ios-dev）", text: $viewModel.channelName)
//                    .textFieldStyle(CapsuleFieldStyle())
//                    .frame(minWidth: 140)
//                TextField("昵称（可带 #口令）", text: $viewModel.nickname)
//                    .textFieldStyle(CapsuleFieldStyle())
//            }
//
//            HStack(spacing: 12) {
//                Toggle("端到端加密", isOn: $viewModel.isEndToEndEncryptionEnabled)
//                    .toggleStyle(SwitchToggleStyle(tint: .mint))
//                if viewModel.isEndToEndEncryptionEnabled {
//                    SecureField("群口令（线下共享）", text: $viewModel.passphraseForEndToEndEncryption)
//                        .textFieldStyle(CapsuleFieldStyle())
//                }
//                Spacer(minLength: 0)
//                Toggle("仅看 @我", isOn: $viewModel.showOnlyMentions)
//                    .toggleStyle(SwitchToggleStyle(tint: .mint))
//                statusPill
//            }
//        }
//        .padding(12)
//        .background(HackTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
//        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HackTheme.panelStroke))
//    }
//
//    // 聊天列表（带搜索/过滤）
//    private var chatScroll: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 10) {
//                    ForEach(filteredMessages()) { msg in
//                        MessageRowView(message: msg,
//                                       myBaseNick: viewModel.nickname.hcBaseNick,
//                                       tsStyle: tsStyle)
//                        .id(msg.id)
//                    }
//                }
//                .padding(.horizontal, 12)
//                .padding(.bottom, 8)
//            }
//            .onReceive(viewModel.$messages) { _ in
//                if let last = filteredMessages().last {
//                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
//                }
//            }
//        }
//    }
//
//    private func filteredMessages() -> [ChatMessage] {
//        let q = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
//        return viewModel.messages.filter { msg in
//            let passSearch: Bool = q.isEmpty || msg.plaintext.localizedCaseInsensitiveContains(q) || (msg.attachment?.fileName?.localizedCaseInsensitiveContains(q) ?? false)
//            let passMention: Bool = !viewModel.showOnlyMentions || msg.plaintext.localizedCaseInsensitiveContains("@\(viewModel.nickname.hcBaseNick)")
//            return passSearch && passMention
//        }
//    }
//
//    // 底部输入栏（+ 附件按钮）
//    private var inputBar: some View {
//        HStack(spacing: 10) {
//            PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .videos])) {
//                Image(systemName: "paperclip.circle.fill").imageScale(.large)
//            }
//            .buttonStyle(.plain)
//
//            Button {
//                showFileImporter = true
//            } label: {
//                Image(systemName: "folder.circle.fill").imageScale(.large)
//            }
//            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.data], allowsMultipleSelection: false) { result in
//                guard case .success(let urls) = result, let url = urls.first else { return }
//                Task { await handleFilePicked(url: url) }
//            }
//
//            TextField("输入消息…（支持 /me、/clear、/join、/nick、/help）", text: $messageDraft, axis: .vertical)
//                .textFieldStyle(CapsuleFieldStyle())
//                .focused($isInputFocused)
//                .onSubmit(sendMessage)
//
//            Button(action: sendMessage) {
//                Label("发送", systemImage: "arrow.up.circle.fill")
//                    .labelStyle(.titleAndIcon)
//            }
//            .buttonStyle(.borderedProminent)
//            .controlSize(.large)
//            .disabled(messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//                      || viewModel.connectionState != .connected)
//        }
//    }
//
//    private func sendMessage() {
//        let text = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !text.isEmpty else { return }
//        viewModel.sendChat(text: text)
//        messageDraft = ""
//        isInputFocused = true
//    }
//
//    // 工具栏：连接/断开
//    private var connectButton: some View {
//        Group {
//            switch viewModel.connectionState {
//            case .connected:
//                Button { viewModel.disconnect() } label: { Label("断开", systemImage: "bolt.slash.fill") }
//            case .connecting:
//                ProgressView().controlSize(.small)
//            case .disconnected:
//                Button { viewModel.connect() } label: { Label("连接", systemImage: "bolt.fill") }
//            }
//        }
//    }
//
//    // 工具栏：时间戳样式
//    private var timestampMenu: some View {
//        Menu {
//            ForEach(TimestampStyle.allCases, id: \.rawValue) { s in
//                Button { tsStyleRaw = s.rawValue } label: {
//                    if tsStyle == s { Label(s.title, systemImage: "checkmark") }
//                    else { Text(s.title) }
//                }
//            }
//        } label: { Image(systemName: "clock") }
//    }
//
//    // 工具栏：@提醒开关
//    private var notifyToggle: some View {
//        Toggle(isOn: $viewModel.mentionNotificationEnabled) {
//            Image(systemName: "bell")
//        }.toggleStyle(.switch)
//    }
//
//    private var searchToggle: some View {
//        Button {
//            // 只有有搜索词时才清空；没词时按钮禁用，仅作图标占位
//            if !viewModel.searchText.isEmpty { viewModel.searchText = "" }
//        } label: {
//            Image(systemName: viewModel.searchText.isEmpty ? "magnifyingglass" : "xmark.circle.fill")
//        }
//        .labelStyle(.iconOnly)
//        .disabled(viewModel.searchText.isEmpty)
//        .accessibilityLabel(viewModel.searchText.isEmpty ? "搜索" : "清除搜索")
//    }
//
//
//    // 右侧状态 pill
//    private var statusPill: some View {
//        let (text, color): (String, Color) = {
//            switch viewModel.connectionState {
//            case .connected: return ("已连接", .green)
//            case .connecting: return ("连接中…", .orange)
//            case .disconnected: return ("未连接", .red)
//            }
//        }()
//        return Label(text, systemImage: "dot.circle.fill")
//            .foregroundStyle(color)
//            .padding(.horizontal, 10)
//            .padding(.vertical, 6)
//            .background(color.opacity(0.12), in: Capsule())
//    }
//
//    // MARK: - 选图/选文件处理
//
//    private func handlePhotoPicked(_ item: PhotosPickerItem) async {
//        do {
//            // 先把二进制拉出来
//            guard let data = try await item.loadTransferable(type: Data.self) else { return }
//
//            // 从 supportedContentTypes 获取类型信息（而不是 loadTransferable(UTType.self)）
//            let utType = item.supportedContentTypes.first
//            let ext = utType?.preferredFilenameExtension ?? "bin"
//            let mime = utType?.preferredMIMEType ?? "application/octet-stream"
//
//            // 写到带扩展名的临时文件，便于后续推断
//            let tmpURL = FileManager.default.temporaryDirectory
//                .appendingPathComponent(UUID().uuidString)
//                .appendingPathExtension(ext)
//            try data.write(to: tmpURL, options: .atomic)
//
//            // 走直传（如需 SecretStream 加密可在这里替换为加密后的 encryptedURL）
//            let meta = try await viewModel.encryptAndUploadIfNeeded(
//                sourceURL: tmpURL,
//                suggestedMime: mime,
//                fileName: nil
//            )
//            viewModel.sendAttachment(meta: meta)
//        } catch {
//            print("photo pick/upload error:", error)
//        }
//    }
//
//
//    private func handleFilePicked(url: URL) async {
//        do {
//            let mime = mimeType(for: url) ?? "application/octet-stream"
//            let meta = try await viewModel.encryptAndUploadIfNeeded(sourceURL: url, suggestedMime: mime, fileName: url.lastPathComponent)
//            viewModel.sendAttachment(meta: meta)
//        } catch {
//            print("file upload error:", error)
//        }
//    }
//
//    private func mimeType(for url: URL) -> String? {
//        if let type = UTType(filenameExtension: url.pathExtension) {
//            return type.preferredMIMEType
//        }
//        return nil
//    }
//}
//
//// MARK: - 样式小组件
//
//struct CapsuleFieldStyle: TextFieldStyle {
//    func _body(configuration: TextField<_Label>) -> some View {
//        configuration
//            .textFieldStyle(.plain)
//            .padding(.horizontal, 12)
//            .padding(.vertical, 8)
//            .background(HackTheme.panel.opacity(0.9), in: Capsule())
//            .overlay(Capsule().stroke(HackTheme.panelStroke))
//            .foregroundStyle(.primary)
//    }
//}
//
//struct MessageRowView: View {
//    let message: ChatMessage
//    let myBaseNick: String
//    let tsStyle: TimestampStyle
//
//    var body: some View {
//        HStack(alignment: .top, spacing: 10) {
//            if message.isFromSelf { Spacer(minLength: 24) }
//            if !message.isFromSelf {
//                Text("[\(message.senderNickname.hcBaseNick)]")
//                    .font(.caption2)
//                    .foregroundStyle(colorForNickname(message.senderNickname))
//                    .padding(.top, 6)
//                    .frame(minWidth: 70, alignment: .trailing)
//            }
//            VStack(alignment: message.isFromSelf ? .trailing : .leading, spacing: 4) {
//                RichMessageText(message: message, myBaseNick: myBaseNick)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(
//                        message.kind == .system ? Color.clear :
//                            (message.isFromSelf ? HackTheme.myBubble : HackTheme.otherBubble),
//                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .stroke(HackTheme.panelStroke)
//                            .opacity(message.kind == .system ? 0 : 1)
//                    )
//
//                if let t = formattedTimestamp(message.timestamp, style: tsStyle) {
//                    Text(t).font(.caption2).foregroundStyle(.secondary)
//                }
//            }
//            if message.isFromSelf {
//                Image(systemName: "person.circle.fill")
//                    .foregroundStyle(Color.accentColor)
//                    .padding(.top, 6)
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: message.isFromSelf ? .trailing : .leading)
//    }
//}
