# 🐛 后台 WebSocket 断线问题修复方案

## 问题描述

用户报告：手机锁屏后立马显示用户离线。

## 根本原因分析

### iOS 后台限制

1. **WebSocket 在后台会被挂起**
   - iOS 会在 App 进入后台后的 **几秒钟内** 暂停所有网络连接
   - 包括 WebSocket 连接
   - 这是 iOS 省电机制的一部分

2. **scenePhase 生命周期**
   ```
   前台 (.active)
       ↓
   锁屏/切换App (.inactive)
       ↓
   完全进入后台 (.background)
       ↓
   WebSocket 被挂起（几秒后）
       ↓
   服务器检测到连接断开
       ↓
   广播用户离线
   ```

3. **重新打开 App 时**
   ```
   从后台切回 (.background → .inactive → .active)
       ↓
   触发 scenePhase onChange
       ↓
   但 WebSocket 已经断开
       ↓
   需要手动重连
   ```

## 解决方案

### 方案 1：后台自动重连（推荐）

在 `HChatApp.swift` 中监听 `scenePhase` 变化，自动重连：

```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    switch newPhase {
    case .active:
        // ✅ App 进入前台
        DebugLogger.log("🟢 App 进入前台，检查 WebSocket 连接", level: .info)
        BadgeManager.shared.clearUnread()
        
        // ✅ 如果 WebSocket 断开，自动重连
        if !client.isConnected {
            if let url = URL(string: "wss://hc.go-lv.com/chat-ws") {
                DebugLogger.log("🔄 后台断线，正在重连 WebSocket...", level: .info)
                client.connect(to: url)
            }
        }
        
    case .inactive:
        DebugLogger.log("🟡 App 进入非活动状态", level: .debug)
        // 不做任何操作，等待进入后台或重新激活
        
    case .background:
        DebugLogger.log("🔵 App 进入后台，WebSocket 将被 iOS 挂起", level: .debug)
        // 不主动断开，让 iOS 自然挂起
        // 这样服务器会在几秒后检测到断线
        
    @unknown default:
        break
    }
}
```

### 方案 2：后台保活（需要后台模式权限）

**注意**：这需要在 Xcode 中启用后台模式：

1. 打开 `Info.plist`
2. 添加 `UIBackgroundModes` 数组
3. 添加 `voip` 或 `audio` 模式

**缺点**：
- 需要额外权限
- 可能被 Apple 审核拒绝（如果没有合理理由）
- 耗电

**不推荐用于聊天应用！**

### 方案 3：优雅的状态提示

在 UI 上显示连接状态，让用户知道发生了什么：

```swift
// ChatView.swift
if client.connectionStatus == .disconnected {
    HStack {
        ProgressView()
        Text("正在重连...")
    }
    .padding()
    .background(Color.orange.opacity(0.2))
}
```

## 实施步骤

### Step 1：修改 HChatApp.swift

添加自动重连逻辑到 `scenePhase` 监听器。

### Step 2：优化 HackChatClient

确保 `connect()` 方法可以多次调用而不会出错。

### Step 3：测试

1. 打开 App，连接到频道
2. 锁屏
3. 等待 5 秒
4. 解锁
5. 验证是否自动重连成功

## 预期效果

### 修复前

```
用户锁屏
    ↓
几秒后 WebSocket 断开
    ↓
服务器广播用户离线
    ↓
解锁手机
    ↓
App 还是断开状态 ❌
    ↓
需要手动重连
```

### 修复后

```
用户锁屏
    ↓
几秒后 WebSocket 断开
    ↓
服务器广播用户离线
    ↓
解锁手机
    ↓
scenePhase 变为 .active
    ↓
检测到 WebSocket 断开
    ↓
自动重连 ✅
    ↓
几秒内恢复在线状态
```

## 其他考虑

### 1. 通知

即使 WebSocket 断开，仍然可以通过 Push Notification 接收消息。
但这需要后端支持 APNs。

### 2. 用户体验

- 显示"正在重连..."提示
- 使用 Toast 通知重连成功/失败
- 禁用发送按钮直到重连成功

### 3. 重连策略

- 立即重连（scenePhase 变为 .active）
- 如果失败，每 3 秒重试一次
- 最多重试 5 次
- 如果还是失败，显示手动重连按钮

## 为什么之前能工作？

可能的原因：
1. 之前有自动重连逻辑，但在某次重构时被移除了
2. 测试时没有真正锁屏足够长的时间（iOS 需要几秒才会挂起）
3. 之前的代码可能有其他 bug 导致连接更容易断开，反而触发了重连逻辑

## 结论

iOS 的后台限制是无法避免的。最佳方案是：
1. ✅ 在 App 切回前台时自动重连
2. ✅ 显示连接状态给用户
3. ✅ 提供手动重连按钮作为备用方案
4. ❌ 不要尝试在后台保持 WebSocket（耗电且不可靠）

