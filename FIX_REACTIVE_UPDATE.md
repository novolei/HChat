# 修复表情和已读回执即时更新问题

## 🐛 问题根源

SwiftUI 的 `@Observable` 在处理嵌套集合时的行为：
- ✅ 可以检测：`messagesByChannel[channel] = newArray`
- ❌ 无法检测：`messagesByChannel[channel][index].property = value`

**关键原因**：直接修改数组元素的属性时，`@Observable` 不会触发变更通知。

## 🔧 解决方案

### 1. 统一的更新模式

在 `ChatState` 中添加 `updateMessage` 方法：

```swift
func updateMessage(in channel: String, messageId: String, updateBlock: (inout ChatMessage) -> Void) {
    var messages = messagesByChannel[channel] ?? []
    guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
        return
    }
    
    updateBlock(&messages[index])  // 修改副本
    
    // 🔥 关键：整体替换数组触发 @Observable
    messagesByChannel[channel] = messages
}
```

### 2. 修复受影响的模块

#### ✅ `ReactionManager.swift`
```swift
// 之前：直接修改（不触发更新）
var message = state.messagesByChannel[channel]![messageIndex]
message.reactions[emoji] = ...
state.messagesByChannel[channel]?[messageIndex] = message  // ❌ 不触发

// 现在：使用 updateMessage
state.updateMessage(in: channel, messageId: messageId) { message in
    message.reactions = newReactions  // ✅ 触发更新
}
```

#### ✅ `ReadReceiptManager.swift`
```swift
// 之前：直接修改（不触发更新）
var message = state.messagesByChannel[channel]![messageIndex]
message.readReceipts.append(receipt)
state.messagesByChannel[channel]?[messageIndex] = message  // ❌ 不触发

// 现在：使用 updateMessage
state.updateMessage(in: channel, messageId: messageId) { message in
    message.readReceipts.append(receipt)  // ✅ 触发更新
    if message.sender == client?.myNick {
        message.status = .read
    }
}
```

#### ✅ `Models.swift`
```swift
// 移除 lazy 惰性计算
public var reactionSummaries: [ReactionSummary] {
    reactions.map { ... }  // 立即计算，返回数组
}
```

## 📊 更新流程

```
用户操作（点击表情/阅读消息）
    ↓
Manager 调用 state.updateMessage()
    ↓
updateBlock 修改消息副本
    ↓
messagesByChannel[channel] = messages  ← 🔥 触发 @Observable
    ↓
SwiftUI 检测到状态变化
    ↓
UI 立即更新！✨
```

## ✅ 修改文件

| 文件 | 修改内容 |
|------|----------|
| `ChatState.swift` | + 添加 `updateMessage()` 统一更新方法 |
| `ReactionManager.swift` | ✏️ 使用 `updateMessage()` 替代直接修改 |
| `ReadReceiptManager.swift` | ✏️ 使用 `updateMessage()` 替代直接修改 |
| `Models.swift` | 🔧 移除 `lazy` 计算 |

## 🎯 效果

- ⚡️ **表情反应**：点击后立即显示徽章
- 📬 **已读回执**：收到回执立即更新 UI
- 📊 **消息状态**：发送/送达状态实时更新
- 🚀 **性能**：数组整体替换，性能影响极小

## 🔍 验证方法

1. 点击表情 → 徽章立即出现
2. 接收已读回执 → 对勾立即变化
3. 发送消息 → 状态图标实时更新
4. 其他用户添加表情 → 立即看到更新

所有更新都应该在操作发生的**当下**立即反映在 UI 上！
