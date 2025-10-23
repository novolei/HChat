# 🔔 通知问题诊断

## 🐛 问题描述

用户报告：
1. App 进入后台时没有通知给 channel
2. 其他用户发来的消息也没有通知显示
3. 桌面 App 图标上也没有 badge 显示

## 🔍 可能的原因

### 1. 工作时间设置问题 ⚠️

查看 `SmartNotificationManager.swift` 第 213-233 行：

```swift
func isWorkingHours() -> Bool {
    guard let workingHours = settings.workingHours, workingHours.enabled else {
        return false  // ✅ 如果未启用，返回 false（非工作时间）
    }
    
    // 检查是否工作日和工作时间...
    return (workingHours.startHour...workingHours.endHour).contains(hour)
}

func shouldNotify(priority: NotificationPriority, channel: String) -> Bool {
    // ...
    let isWorking = isWorkingHours()
    
    if isWorking {
        // 工作时间：只通知紧急消息
        return priority == .urgent
    } else {
        // 非工作时间：通知所有非静音消息
        return priority != .silent
    }
}
```

**问题**：默认设置中 `workingHours.enabled = true`（第 55 行），这意味着：
- 工作时间（9:00-18:00，周一至周五）：**只通知紧急消息**（@mention）
- 非工作时间：通知所有消息

但是，`determinePriority` 的逻辑（第 154 行）：
- 只有 @mention、私聊、关键词才是 `urgent`
- **普通频道消息是 `normal` 优先级**

**结论**：在工作时间，普通频道消息不会通知！

### 2. 后台运行限制

iOS 的后台限制：
- App 进入后台后，WebSocket 连接会在几秒内被系统挂起
- 本地通知只能在 App 前台运行时发送
- **需要服务器推送 APNs 才能在后台收到通知**

### 3. 通知权限

检查是否正确授权通知权限。

## ✅ 解决方案

### 方案 1: 调整工作时间默认设置（推荐）

修改默认设置，让所有时间都接收通知：

```swift
// SmartNotificationManager.swift
struct Settings: Codable, Equatable {
    var enabled: Bool = true
    var urgentOnly: Bool = false
    var keywords: [String] = []
    var mutedChannels: [String] = []
    var workingHours: WorkingHours? = nil  // ✅ 改为 nil，禁用工作时间限制
    var groupByChannel: Bool = true
    
    struct WorkingHours: Codable, Equatable {
        var enabled: Bool = false  // ✅ 改为 false
        var startHour: Int = 9
        var endHour: Int = 18
        var weekdaysOnly: Bool = true
    }
}
```

### 方案 2: 简化通知逻辑

直接移除工作时间判断，让所有非静音消息都通知：

```swift
func shouldNotify(priority: NotificationPriority, channel: String) -> Bool {
    // 静音频道不通知
    if priority == .silent {
        return false
    }
    
    // 仅紧急消息模式
    if settings.urgentOnly && priority != .urgent {
        return false
    }
    
    // ✅ 直接返回 true，移除工作时间判断
    return true
}
```

### 方案 3: 实现 APNs 后台推送（长期方案）

要真正实现后台通知，需要：

1. **后端改造**：
   - 当用户不在线时，服务器发送 APNs 推送
   - 需要存储用户的 device token
   - 需要配置 APNs 证书

2. **客户端改造**：
   - 注册 APNs
   - 上传 device token 到服务器
   - 处理 APNs 推送

## 🎯 推荐行动

1. **立即修复**：采用方案 1，将 `workingHours` 默认设置为 `nil` 或 `enabled = false`
2. **测试验证**：在 App 前台时，普通消息是否能收到通知
3. **长期规划**：如果需要真正的后台通知，需要实现 APNs

## ⚠️ 注意

当前的通知系统**只在 App 前台运行时有效**：
- App 在前台：可以通过 `UNUserNotificationCenter` 显示本地通知
- App 在后台：WebSocket 断开，收不到消息，也就无法发送本地通知
- 需要 APNs 才能实现真正的后台推送

## 📱 测试步骤

1. 修改代码
2. 清除 App 数据（重置设置）
3. 重新安装
4. 在前台时测试：
   - 发送普通消息 → 应该有通知
   - 发送 @mention → 应该有通知
   - 检查 badge 是否更新
5. 进入后台测试：
   - 期望：前台的其他设备发消息，当前设备不会收到（需要 APNs）
