# 🚀 P1 功能实施计划

**基于：** P0 全部完成（消息可靠性、搜索增强、通知优化）  
**开始日期：** 2025-10-21  
**预计完成：** 2-3 周  

---

## 📋 P1 功能概览

| 功能 | 优先级 | 预计时间 | 价值 | 难度 |
|------|--------|---------|------|------|
| 已读回执 | P1 | 2-3 天 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 语音消息 | P1 | 3-4 天 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 表情回应 | P1 | 2-3 天 | ⭐⭐⭐⭐ | ⭐⭐ |
| 消息引用/回复 | P1 | 2-3 天 | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| 在线状态指示器 | P1 | 1-2 天 | ⭐⭐⭐ | ⭐⭐ |

---

## 🎯 功能 1: 已读回执（Read Receipts）

### 目标
让发送者知道消息是否被阅读，类似 WhatsApp/微信的"已读"功能。

### 技术方案

#### 1.1 消息状态扩展

**文件：** `Core/Models/MessageStatus.swift`（已有）

增强现有的 `read` 状态：
```swift
// 已有状态
case read       // ✓✓ 已读

// 添加已读时间和读者信息
struct ReadReceipt {
    let userId: String
    let readAt: Date
}

extension ChatMessage {
    var readReceipts: [ReadReceipt] = []
    var isRead: Bool {
        !readReceipts.isEmpty
    }
}
```

#### 1.2 客户端实现

**文件：** `Core/Services/ReadReceiptManager.swift`（新建）

```swift
@MainActor
@Observable
final class ReadReceiptManager {
    private weak var client: HackChatClient?
    
    // 发送已读回执
    func markAsRead(messageIds: [String], channel: String) {
        client?.send(json: [
            "type": "read_receipt",
            "messageIds": messageIds,
            "channel": channel,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // 处理收到的已读回执
    func handleReadReceipt(_ data: [String: Any]) {
        // 更新消息状态
    }
}
```

#### 1.3 后端支持

**文件：** `chat-gateway/src/handlers/readReceiptHandler.js`（新建）

```javascript
function handleReadReceipt(ws, msg) {
  const { messageIds, channel } = msg;
  
  // 广播已读回执给消息发送者
  broadcast(channel, {
    type: 'read_receipt',
    messageIds: messageIds,
    reader: ws.nick,
    timestamp: Date.now()
  }, ws);  // 不发给自己
}
```

#### 1.4 UI 显示

**文件：** `UI/Components/ReadReceiptView.swift`（新建）

```swift
struct ReadReceiptView: View {
    let message: ChatMessage
    
    var body: some View {
        if message.isRead {
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("已读")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

**功能：**
- ✅ 消息滚动到可见区域时自动发送已读回执
- ✅ 显示"已读"标记和时间
- ✅ 点击查看谁已读（群聊场景）

---

## 🎤 功能 2: 语音消息（Voice Messages）

### 目标
支持录制和播放语音消息，类似微信语音。

### 技术方案

#### 2.1 录音管理器

**文件：** `Core/Services/AudioRecorderManager.swift`（新建）

```swift
import AVFoundation

@MainActor
@Observable
final class AudioRecorderManager {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    
    // 开始录音
    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord)
        try session.setActive(true)
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        
        recordingURL = url
        isRecording = true
    }
    
    // 停止录音
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return recordingURL
    }
}
```

#### 2.2 音频播放器

**文件：** `Core/Services/AudioPlayerManager.swift`（新建）

```swift
import AVFoundation

@MainActor
@Observable
final class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?
    
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    
    // 播放语音
    func play(url: URL) async throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        duration = audioPlayer?.duration ?? 0
        audioPlayer?.play()
        isPlaying = true
        
        // 监听播放进度
        startProgressTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0
    }
}
```

#### 2.3 语音消息 UI

**文件：** `UI/Components/VoiceMessageView.swift`（新建）

```swift
struct VoiceMessageView: View {
    let voiceMessage: VoiceAttachment
    @State private var player = AudioPlayerManager()
    
    var body: some View {
        HStack {
            // 播放/暂停按钮
            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    Task { try? await player.play(url: voiceMessage.url) }
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
            }
            
            // 波形或进度条
            VoiceWaveformView(duration: voiceMessage.duration, currentTime: player.currentTime)
            
            // 时长
            Text(formatDuration(voiceMessage.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```

#### 2.4 录音 UI

**文件：** `Views/Chat/VoiceRecordButton.swift`（新建）

长按录音按钮：
```swift
struct VoiceRecordButton: View {
    @State private var recorder = AudioRecorderManager()
    @State private var isRecording = false
    let onRecordingComplete: (URL) -> Void
    
    var body: some View {
        Button {
            // 点击无效，需要长按
        } label: {
            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title)
                .foregroundColor(isRecording ? .red : .blue)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // 开始录音
                    Task {
                        try? await recorder.startRecording()
                        isRecording = true
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    // 结束录音
                    if let url = recorder.stopRecording() {
                        onRecordingComplete(url)
                    }
                    isRecording = false
                }
        )
    }
}
```

**功能：**
- ✅ 长按录音，松手发送
- ✅ 上滑取消录音
- ✅ 实时显示录音时长
- ✅ 波形动画
- ✅ 播放语音消息
- ✅ 倍速播放（1.0x, 1.5x, 2.0x）

---

## 😊 功能 3: 表情回应（Emoji Reactions）

### 目标
对消息快速反应（点赞、爱心等），类似 iMessage/Slack。

### 技术方案

#### 3.1 反应模型

**文件：** `Core/Models/MessageReaction.swift`（新建）

```swift
struct MessageReaction: Identifiable, Codable {
    let id: String
    let emoji: String           // 😀👍❤️🎉
    let userId: String
    let username: String
    let timestamp: Date
}

extension ChatMessage {
    var reactions: [String: [MessageReaction]] = [:]  // emoji -> users
    
    var hasReactions: Bool {
        !reactions.isEmpty
    }
}
```

#### 3.2 反应管理器

**文件：** `Core/Services/ReactionManager.swift`（新建）

```swift
@MainActor
@Observable
final class ReactionManager {
    private weak var client: HackChatClient?
    
    // 添加反应
    func addReaction(emoji: String, to messageId: String, channel: String) {
        client?.send(json: [
            "type": "add_reaction",
            "messageId": messageId,
            "channel": channel,
            "emoji": emoji,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // 移除反应
    func removeReaction(emoji: String, from messageId: String, channel: String) {
        client?.send(json: [
            "type": "remove_reaction",
            "messageId": messageId,
            "channel": channel,
            "emoji": emoji
        ])
    }
}
```

#### 3.3 反应选择器 UI

**文件：** `UI/Components/EmojiReactionPicker.swift`（新建）

```swift
struct EmojiReactionPicker: View {
    let onSelect: (String) -> Void
    
    let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🎉"]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(quickReactions, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji)
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}
```

#### 3.4 反应显示

**文件：** `UI/Components/ReactionBubblesView.swift`（新建）

```swift
struct ReactionBubblesView: View {
    let reactions: [String: [MessageReaction]]
    let onTap: (String) -> Void  // 切换自己的反应
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(reactions.keys).sorted(), id: \.self) { emoji in
                ReactionBubble(
                    emoji: emoji,
                    count: reactions[emoji]?.count ?? 0,
                    isMyReaction: reactions[emoji]?.contains { $0.userId == myUserId } ?? false
                ) {
                    onTap(emoji)
                }
            }
        }
    }
}

struct ReactionBubble: View {
    let emoji: String
    let count: Int
    let isMyReaction: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 2) {
                Text(emoji)
                if count > 1 {
                    Text("\(count)")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isMyReaction ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}
```

**交互：**
- 长按消息 → 显示快捷反应选择器
- 点击反应泡泡 → 切换自己的反应
- 长按反应泡泡 → 查看反应者列表

---

## 💬 功能 4: 消息引用/回复（Message Reply）

### 目标
回复特定消息，保持对话上下文。

### 技术方案

#### 4.1 引用模型

**文件：** `Core/Models/MessageReply.swift`（新建）

```swift
struct MessageReply: Codable {
    let messageId: String
    let sender: String
    let text: String
    let timestamp: Date
}

extension ChatMessage {
    var replyTo: MessageReply?
}
```

#### 4.2 引用管理器

**文件：** `Core/Services/ReplyManager.swift`（新建）

```swift
@MainActor
@Observable
final class ReplyManager {
    var replyingTo: ChatMessage?
    
    // 设置回复目标
    func setReplyTarget(_ message: ChatMessage) {
        replyingTo = message
    }
    
    // 清除回复
    func clearReply() {
        replyingTo = nil
    }
    
    // 发送回复
    func sendReply(text: String, client: HackChatClient) {
        guard let target = replyingTo else { return }
        
        client.send(json: [
            "type": "message",
            "text": text,
            "replyTo": [
                "messageId": target.id,
                "sender": target.sender,
                "text": target.text.prefix(100)  // 截断长文本
            ]
        ])
        
        clearReply()
    }
}
```

#### 4.3 引用预览 UI

**文件：** `UI/Components/ReplyPreviewBar.swift`（新建）

```swift
struct ReplyPreviewBar: View {
    let replyTo: ChatMessage
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("回复 \(replyTo.sender)")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(replyTo.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}
```

#### 4.4 引用消息显示

**文件：** `UI/Components/QuotedMessageView.swift`（新建）

```swift
struct QuotedMessageView: View {
    let reply: MessageReply
    let onTap: () -> Void  // 跳转到原消息
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(reply.sender)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text(reply.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
```

---

## 🟢 功能 5: 在线状态指示器（Online Status）

### 目标
实时显示用户在线/离线状态。

### 技术方案

#### 5.1 状态模型

**文件：** `Core/Models/UserStatus.swift`（新建）

```swift
enum UserStatus: String, Codable {
    case online     // 🟢 在线
    case away       // 🟡 离开
    case busy       // 🔴 忙碌
    case offline    // ⚪ 离线
    
    var color: Color {
        switch self {
        case .online: return .green
        case .away: return .yellow
        case .busy: return .red
        case .offline: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .online: return "circle.fill"
        case .away: return "moon.fill"
        case .busy: return "minus.circle.fill"
        case .offline: return "circle"
        }
    }
}
```

#### 5.2 状态管理器

**文件：** `Core/Services/PresenceManager.swift`（新建）

```swift
@MainActor
@Observable
final class PresenceManager {
    private weak var client: HackChatClient?
    
    var userStatuses: [String: UserStatus] = [:]  // userId -> status
    var lastSeen: [String: Date] = [:]            // userId -> lastSeen
    
    // 更新自己的状态
    func updateMyStatus(_ status: UserStatus) {
        client?.send(json: [
            "type": "status_update",
            "status": status.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // 处理收到的状态更新
    func handleStatusUpdate(_ data: [String: Any]) {
        guard let userId = data["userId"] as? String,
              let statusRaw = data["status"] as? String,
              let status = UserStatus(rawValue: statusRaw) else { return }
        
        userStatuses[userId] = status
        
        if let timestamp = data["timestamp"] as? TimeInterval {
            lastSeen[userId] = Date(timeIntervalSince1970: timestamp)
        }
    }
}
```

#### 5.3 状态指示器 UI

**文件：** `UI/Components/UserStatusIndicator.swift`（新建）

```swift
struct UserStatusIndicator: View {
    let status: UserStatus
    let size: CGFloat = 12
    
    var body: some View {
        ZStack {
            Circle()
                .fill(status.color)
                .frame(width: size, height: size)
            
            if status == .busy {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
    }
}
```

---

## 📊 实施优先级建议

### 推荐顺序

#### 第1周：基础功能
1. **在线状态指示器**（最简单，1-2天）
   - 用户体验提升明显
   - 技术难度低
   - 可以快速见效

2. **表情回应**（2-3天）
   - 用户互动性强
   - 实现相对简单
   - 增加趣味性

#### 第2周：核心功能
3. **消息引用/回复**（2-3天）
   - 提升对话体验
   - 中等难度
   - 高价值

4. **已读回执**（2-3天）
   - 用户强需求
   - 需要后端配合
   - 高价值

#### 第3周：高级功能
5. **语音消息**（3-4天）
   - 最复杂的功能
   - 需要音频权限
   - 需要UI/UX精心设计

---

## 🎯 技术要点

### 通用考虑

1. **向下兼容**
   - 所有新功能都要兼容旧版本
   - 旧客户端收到新消息类型时优雅降级

2. **性能优化**
   - 语音消息压缩
   - 反应聚合（避免大量网络请求）
   - 状态更新节流

3. **安全性**
   - 语音消息加密
   - 已读回执隐私设置
   - 状态可见性控制

---

## 📝 下一步行动

请选择您想要优先实现的功能：

1. **🟢 在线状态**（快速见效）
2. **😊 表情回应**（趣味性强）
3. **💬 消息引用**（实用性高）
4. **✓✓ 已读回执**（用户需求）
5. **🎤 语音消息**（功能丰富）

或者您有其他想优先实现的功能？

---

**准备好了，请告诉我从哪个功能开始！** 🚀

