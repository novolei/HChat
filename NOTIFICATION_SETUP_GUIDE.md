# 📱 iOS 通知配置指南

## ⚠️ 重要：通知无法显示？

如果您发现 iOS 端通知不显示或没有声音，请按照以下步骤配置：

---

## 1. Xcode 项目设置

### 1.1 添加 Push Notifications Capability

1. 打开 Xcode 项目
2. 选择 **HChat** target
3. 点击 **Signing & Capabilities** 标签
4. 点击 **+ Capability** 按钮
5. 搜索并添加 **Push Notifications**

### 1.2 添加 Background Modes（可选）

如果需要后台通知：

1. 在 **Signing & Capabilities** 中
2. 添加 **Background Modes**
3. 勾选：
   - ☑️ **Remote notifications**
   - ☑️ **Background fetch**（可选）

---

## 2. Info.plist 配置

虽然现代 SwiftUI 项目可能不需要显式的 Info.plist，但如果您的项目有 Info.plist 文件，请添加以下权限说明：

### 方法 A：在 Xcode 中添加

1. 找到项目中的 `Info.plist` 文件
2. 右键 → **Open As** → **Source Code**
3. 在 `<dict>` 标签内添加：

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>HChat 需要发送通知来提醒您新消息、@提及和重要事件</string>
```

### 方法 B：使用 Info tab

1. 选择项目 target
2. 点击 **Info** 标签
3. 点击 **+** 添加新行
4. 选择 **Privacy - User Notifications Usage Description**
5. 输入：`HChat 需要发送通知来提醒您新消息、@提及和重要事件`

---

## 3. 代码中请求权限

代码已经自动处理了权限请求，在 `SmartNotificationManager` 初始化时会自动请求。

但为了确保万无一失，您可以在 `HChatApp.swift` 中显式调用：

```swift
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
                    
                    // 连接 WebSocket
                    if let url = URL(string: "wss://hc.go-lv.com/chat-ws") {
                        client.connect(to: url)
                    }
                }
        }
    }
}
```

---

## 4. 真机测试

**⚠️ 重要：模拟器可能无法正确显示通知！**

请确保：

1. ✅ 使用 **真机** 测试通知功能
2. ✅ 在设备的 **设置** → **通知** → **HChat** 中检查：
   - 允许通知：✅ 开启
   - 声音：✅ 开启
   - 标记：✅ 开启
   - 横幅：✅ 开启

---

## 5. 检查通知权限状态

在 App 中测试通知设置：

1. 打开 HChat
2. 进入 **通知设置**（如果有设置界面）
3. 点击 **发送测试通知** 按钮
4. 应该会收到一条测试通知

如果没有收到：

### 步骤 A：检查系统权限

```swift
// 添加临时调试代码
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print("通知权限状态：", settings.authorizationStatus)
    // 0 = notDetermined（未决定）
    // 1 = denied（已拒绝）
    // 2 = authorized（已授权）
    // 3 = provisional（临时授权）
    // 4 = ephemeral（临时）
}
```

### 步骤 B：手动请求权限

如果状态是 `denied`，需要引导用户：

1. 告知用户前往 **设置** → **HChat** → **通知**
2. 手动开启通知权限

---

## 6. 常见问题

### Q: 为什么没有收到通知？

**A:** 检查以下几点：

1. ✅ 是否在真机测试（模拟器通知可能不可靠）
2. ✅ 系统设置中是否允许通知
3. ✅ App 是否在后台（前台时通知可能不显示横幅）
4. ✅ 是否启用了免打扰模式（勿扰模式）
5. ✅ 设备音量是否静音

### Q: 如何测试通知？

**A:** 使用 `NotificationSettingsView` 中的"发送测试通知"功能：

```swift
// 在任何地方调用
Task {
    let content = UNMutableNotificationContent()
    content.title = "测试通知"
    content.body = "通知功能正常工作！"
    content.sound = .default
    
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )
    
    try? await UNUserNotificationCenter.current().add(request)
}
```

### Q: 为什么只看到通知不播放声音？

**A:** 可能原因：

1. 设备处于静音模式（检查侧边静音开关）
2. 通知设置中声音被关闭
3. 代码中 `content.sound` 未设置或设为 `nil`

确保代码中有：
```swift
content.sound = .default  // ✅ 正确
```

### Q: App 在前台时收不到通知？

**A:** 这是正常的 iOS 行为。前台时通知不会显示横幅，但可以实现 `UNUserNotificationCenterDelegate` 来自定义前台通知行为。

---

## 7. 调试技巧

### 7.1 查看通知日志

在代码中添加日志：

```swift
DebugLogger.log("🔔 发送通知: \(messageId)", level: .info)
```

### 7.2 使用断点

在 `SmartNotificationManager.swift` 的 `send(content:identifier:)` 方法设置断点，检查是否被调用。

### 7.3 检查错误

```swift
do {
    try await UNUserNotificationCenter.current().add(request)
    print("✅ 通知发送成功")
} catch {
    print("❌ 通知发送失败: \(error)")
}
```

---

## 8. 最佳实践

### 8.1 请求权限时机

- ✅ **推荐：** 在用户首次使用相关功能时请求
- ❌ **不推荐：** App 启动立即请求

### 8.2 权限说明

向用户清楚说明为什么需要通知权限：

```swift
.alert("开启通知", isPresented: $showNotificationPrompt) {
    Button("去设置") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    Button("稍后", role: .cancel) {}
} message: {
    Text("开启通知后，您可以及时收到 @提及、私聊消息和重要事件提醒")
}
```

---

## 9. 通知类型说明

HChat 支持的通知类型：

| 类型 | 优先级 | 声音 | 显示时机 |
|------|--------|------|----------|
| @提及 | 紧急 | ✅ | 立即 |
| 私聊 | 紧急 | ✅ | 立即 |
| 关键词 | 紧急 | ✅ | 立即 |
| 普通消息 | 普通 | ✅ | 根据设置 |
| 静音频道 | 静音 | ❌ | 不通知 |

---

## 10. 总结

确保以下所有步骤都已完成：

- [ ] Xcode 添加 Push Notifications capability
- [ ] Info.plist 添加权限说明（如果需要）
- [ ] 代码中请求通知权限
- [ ] **使用真机测试**
- [ ] 检查系统设置中通知权限已开启
- [ ] 测试通知功能是否正常

如果完成以上所有步骤后仍有问题，请检查：

1. Xcode 控制台的错误日志
2. 设备的通知中心是否收到通知
3. 是否有其他 App 干扰通知

---

**祝您使用愉快！** 🎉

如有问题，请查看 `SmartNotificationManager.swift` 和 `NotificationSettingsView.swift` 的实现。

