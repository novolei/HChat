# 🐛 已读回执问题修复

## 🔍 问题分析

用户报告了两个问题：
1. App 在后台时，收到的消息立即显示为"已读"（蓝色）
2. 状态显示为单勾而不是双勾

## 🕵️ 根本原因

### 问题 1：后台立即发送已读回执

**代码位置**：`ChatMessageListView.swift` 第 252-257 行

```swift
.onAppear {
    if message.sender != client.myNick && !hasMarkedRead.contains(message.id) {
        hasMarkedRead.insert(message.id)
        client.readReceiptManager.markAsRead(messageId: message.id, channel: message.channel)
    }
}
```

**问题**：
- 消息一被添加到列表就触发 `.onAppear`
- **即使 App 在后台**，消息也会被添加到 `messagesByChannel`
- SwiftUI 会预渲染列表，触发 `.onAppear`
- 立即发送已读回执 ❌

**应该的逻辑**：
- 只有当消息**真正在屏幕上可见**时才发送已读回执
- 或者只在 **App 在前台且聊天界面打开**时发送

### 问题 2：收到的消息状态流转错误

**代码位置**：`Models.swift` 第 78 行

```swift
public init(..., status: MessageStatus = .sent, ...) {
    // 默认状态是 .sent
}
```

**问题流程**：
```
收到消息
    ↓
创建 ChatMessage，status = .sent（默认值）
    ↓
发送 delivered_receipt（在 MessageHandler 中）
    ↓
但自己的消息状态已经是 .sent 了
    ↓
立即触发 .onAppear
    ↓
发送 read_receipt
    ↓
自己收到 read_receipt 回执
    ↓
但这是自己发的，被忽略了
    ↓
状态保持 .sent（单勾）
```

**实际显示**：
- 图标：`checkmark`（单勾）✓
- 颜色：蓝色（因为某些原因状态被设置为 `.read`）

## ✅ 解决方案

### 方案 1：修复已读回执触发时机（推荐）

#### 选项 A：使用可见性检测（iOS 17+）

```swift
// 使用 .onAppear 和 scenePhase 结合
@Environment(\.scenePhase) private var scenePhase

// 在 MessageRow 中
.onAppear {
    // 只在前台时发送已读回执
    if scenePhase == .active && message.sender != client.myNick {
        markAsReadIfVisible(message)
    }
}
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        markVisibleMessages()
    }
}
```

#### 选项 B：批量标记（当前最佳）

```swift
// 不在每个消息的 .onAppear 中发送
// 而是在整个列表可见时批量发送

// 在 ChatMessageListView 中
.onAppear {
    // App 进入前台或打开聊天时
    markVisibleMessagesAsRead()
}

.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        markVisibleMessagesAsRead()
    }
}

private func markVisibleMessagesAsRead() {
    let visibleMessages = filteredMessages.suffix(20) // 假设最后 20 条可见
    client.readReceiptManager.markVisibleMessagesAsRead(visibleMessages)
}
```

### 方案 2：修复消息状态初始化

#### 区分自己发送和收到的消息

```swift
// MessageHandler.swift - 收到消息时
let message = ChatMessage(
    id: msgId,
    channel: channel,
    sender: nick,
    text: text,
    attachments: attachments,
    status: .sent,  // ← 收到的消息应该是什么状态？
    replyTo: replyTo
)
```

**建议**：
- 收到的消息不应该有"发送状态"
- 只有**自己发送**的消息才需要状态追踪
- 收到的消息可以用 `nil` 或 `.none` 表示"无状态"

#### 方案 2a：让 status 可选

```swift
public var status: MessageStatus?  // 可选

// 收到的消息
status = nil  // 不需要状态

// 自己发送的消息
status = .sending → .sent → .delivered → .read
```

#### 方案 2b：只在 UI 层判断

```swift
// MessageStatusIndicator.swift
var body: some View {
    // 只为自己发送的消息显示状态
    guard message.sender == myNick else { return AnyView(EmptyView()) }
    // ...（当前已经这样做了）
}
```

### 方案 3：修复已读回执的处理逻辑

**问题**：发送方收到自己的已读回执

```swift
// ReadReceiptManager.swift
func handleReadReceipt(_ obj: [String: Any]) {
    guard userId != client?.myNick else { return }  // ← 忽略自己的回执
}
```

**这是对的！** 但是...可能其他地方又设置了状态。

## 🎯 推荐修复步骤

### Step 1：移除每行的 .onAppear 中的 markAsRead

```swift
// MessageListContent 的 row() 方法
// ❌ 删除这段代码
.onAppear {
    if message.sender != client.myNick && !hasMarkedRead.contains(message.id) {
        hasMarkedRead.insert(message.id)
        client.readReceiptManager.markAsRead(...)
    }
}
```

### Step 2：在 ChatView 层面批量标记

```swift
// ChatMessageListView.swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        // App 进入前台，标记可见消息为已读
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let visibleMessages = Array(filteredMessages.suffix(20))
            client.readReceiptManager.markVisibleMessagesAsRead(visibleMessages)
        }
    }
}
```

### Step 3：确保收到的消息不会错误显示状态

收到的消息不应该有状态图标（当前已经做到了），所以这个问题只是显示问题。

## 🧪 测试验证

### 场景 1：App 在前台

```
对方发消息
    ↓
你的 App 收到消息
    ↓
消息添加到列表
    ↓
消息在屏幕上可见
    ↓
延迟 0.5 秒后批量发送已读回执
    ↓
对方收到 read_receipt
    ↓
对方的消息状态变为 .read（蓝色双勾）
```

### 场景 2：App 在后台

```
对方发消息
    ↓
你的 App 在后台（WebSocket 挂起）
    ↓
收不到消息 ❌
    ↓
不会发送已读回执 ✅
    ↓
对方的消息保持 .sent 或 .delivered
```

### 场景 3：从后台切回前台

```
App 切回前台
    ↓
scenePhase 变为 .active
    ↓
触发 onChange
    ↓
延迟 0.5 秒
    ↓
批量标记可见消息为已读
    ↓
发送 read_receipt
    ↓
对方的消息变为 .read
```

## 📊 预期效果

### 修复后的行为

| 场景 | 当前行为 | 期望行为 | 修复后 |
|------|----------|----------|--------|
| 前台收消息 | 立即已读 ❌ | 延迟已读 | ✅ |
| 后台收消息 | 立即已读 ❌ | 不发回执 | ✅ |
| 切回前台 | 无反应 | 批量已读 | ✅ |
| 双勾显示 | 单勾 ❌ | 双勾 | ✅（状态正确） |

## 🚀 实施计划

1. 修改 `ChatMessageListView.swift` - 移除单个消息的 `.onAppear` 已读标记
2. 添加 `scenePhase` 监听 - 在前台时批量标记
3. 测试三种场景
4. 提交代码
