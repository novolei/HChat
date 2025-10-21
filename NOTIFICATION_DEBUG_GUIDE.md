# 🔍 通知功能调试指南

## 问题：真机测试，App 在后台，仍然收不到通知

---

## ✅ 最新修复

刚刚修复了以下关键问题：

1. **MessageHandler 调用错误** - 已从旧的 `NotificationManager` 改为新的 `SmartNotificationManager`
2. **添加详细日志** - 现在每个步骤都有日志输出
3. **权限检查增强** - 发送通知前会检查权限状态

---

## 📱 立即调试步骤

### 步骤 1：查看 Xcode 控制台日志

运行 App 后，在 Xcode 控制台查找以下日志：

#### 预期看到的日志（成功流程）：

```
🔔 收到消息，准备发送通知: <message-id> from <sender>
📊 消息优先级: normal (或 urgent)
⏰ 工作时间检查: 否
🌙 非工作时间，通知所有非静音消息: true
📤 准备发送通知到系统...
🔐 通知权限状态: 2
✅ 通知权限已授予
🎉 通知已成功发送到系统: <message-id>
📱 通知标题: #lobby · sender
📱 通知内容: Hello world
```

#### 如果看到这些日志，说明问题在哪里：

**1. 通知权限被拒绝**
```
🔐 通知权限状态: 1
❌ 通知权限被拒绝！请前往系统设置开启
```
**解决：** 前往 **设置 → HChat → 通知 → 允许通知** 开启

**2. 通知已禁用**
```
🔕 通知已禁用，跳过
```
**解决：** 在 App 的通知设置中开启通知

**3. 仅紧急模式**
```
⚠️ 仅紧急模式，忽略普通消息
```
**解决：** 关闭"仅紧急消息"开关，或发送 @mention 测试

**4. 工作时间限制**
```
🏢 工作时间，仅通知紧急消息: false
```
**解决：** 关闭"工作时间免打扰"，或发送 @mention 测试

**5. 频道已静音**
```
🔇 频道已静音: lobby
```
**解决：** 在通知设置中取消静音该频道

---

### 步骤 2：检查通知权限状态

在 App 启动时会显示权限状态：

```
🔐 通知权限状态: X
```

权限状态对照表：
- `0` = **notDetermined**（未决定）→ 需要请求权限
- `1` = **denied**（已拒绝）→ ❌ 需要去系统设置开启
- `2` = **authorized**（已授权）→ ✅ 正常
- `3` = **provisional**（临时授权）→ ✅ 可用
- `4` = **ephemeral**（临时）→ ✅ 可用

---

### 步骤 3：发送测试消息

#### 测试 1：普通消息

1. 将 App 切到后台
2. 从另一台设备或 Web 版本发送：`Hello from test`
3. **预期：** 如果不在工作时间，应收到通知

#### 测试 2：@mention 消息

1. 将 App 切到后台
2. 从另一台设备发送：`@YourNick 你好`（替换 YourNick 为您的昵称）
3. **预期：** 一定会收到通知（优先级高）

#### 测试 3：私聊消息

1. 将 App 切到后台
2. 从另一台设备发送私聊消息
3. **预期：** 一定会收到通知（优先级高）

---

### 步骤 4：检查通知设置

在 App 内检查以下设置：

```swift
// 打印当前设置（添加临时调试代码）
let settings = SmartNotificationManager.shared.settings
print("📋 通知设置:")
print("  enabled: \(settings.enabled)")
print("  urgentOnly: \(settings.urgentOnly)")
print("  groupByChannel: \(settings.groupByChannel)")
print("  workingHours: \(settings.workingHours?.enabled ?? false)")
print("  mutedChannels: \(settings.mutedChannels)")
```

---

### 步骤 5：强制发送测试通知

在 App 的任何地方添加临时测试代码：

```swift
Button("🧪 强制测试通知") {
    Task {
        let content = UNMutableNotificationContent()
        content.title = "强制测试"
        content.body = "如果看到这个通知，说明通知功能正常！"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 测试通知已发送")
        } catch {
            print("❌ 测试通知失败: \(error)")
        }
    }
}
```

---

## 🔧 常见问题排查

### Q1: Xcode 控制台完全没有通知相关日志

**可能原因：**
- MessageHandler 没有收到消息
- WebSocket 连接有问题

**排查：**
查找日志：
```
📥 收到消息 - ID: xxx
```

如果没有这个日志，说明根本没收到消息，问题在 WebSocket 连接。

---

### Q2: 看到"通知已成功发送"，但设备没显示

**可能原因：**
1. App 在前台（iOS 默认前台不显示横幅）
2. 设备处于勿扰模式
3. 通知被系统延迟

**解决：**
1. 确保 App **完全在后台**（按 Home 键或上滑）
2. 检查控制中心，勿扰模式是否开启
3. 等待 5-10 秒
4. 下拉通知中心查看是否有通知

---

### Q3: 工作时间内收不到通知

**原因：** 工作时间只通知紧急消息

**解决：**
1. 临时关闭"工作时间免打扰"
2. 或发送 @mention 测试（优先级高）

---

### Q4: 通知权限状态一直是 0（未决定）

**原因：** 权限请求对话框未弹出或被快速关闭

**解决：**
1. 完全删除 App
2. 重新安装
3. 首次运行时会弹出权限请求
4. **点击"允许"**

---

## 📊 完整的通知流程检查清单

请依次检查每一项：

### A. Xcode 项目配置
- [ ] 已添加 **Push Notifications** capability
- [ ] Target 签名正常

### B. 系统权限
- [ ] 设置 → HChat → 通知 → 允许通知 ✅
- [ ] 声音 ✅
- [ ] 横幅 ✅
- [ ] 勿扰模式 ❌（关闭）

### C. App 内设置
- [ ] 通知设置 → 启用通知 ✅
- [ ] "仅紧急消息" ❌（关闭，除非测试 @mention）
- [ ] 当前频道没有在"静音频道"列表中
- [ ] "工作时间免打扰" ❌（关闭，除非测试紧急消息）

### D. 测试环境
- [ ] 使用真机（不是模拟器）
- [ ] App 在后台运行
- [ ] 设备未静音
- [ ] 查看 Xcode 控制台日志

### E. 消息类型
- [ ] 尝试普通消息
- [ ] ✅ **强烈推荐：尝试 @mention 消息（优先级最高）**
- [ ] 尝试私聊消息

---

## 🎯 快速诊断命令

将 App 切到后台后，在另一台设备发送：

```
@YourNick 测试通知
```

**如果收到通知：** ✅ 通知功能正常，只是普通消息被过滤了

**如果没收到：** 
1. 查看 Xcode 日志中的 `🔐 通知权限状态`
2. 如果是 `1`（denied），去系统设置开启
3. 如果是 `2`（authorized），检查是否真的在后台

---

## 🆘 仍然无法解决？

### 最后的调试手段

1. **完全重置 App 权限**
   ```bash
   # 在设置中删除 HChat
   # 重新从 Xcode 安装
   ```

2. **检查设备通知中心**
   - 下拉通知中心
   - 查看是否有 HChat 的通知（可能被静默显示）

3. **临时禁用所有过滤**
   - 关闭"仅紧急消息"
   - 关闭"工作时间免打扰"
   - 清空"静音频道"列表
   - 发送 @mention 消息测试

4. **查看完整日志**
   ```
   在 Xcode 控制台搜索：
   - "🔔" （通知相关）
   - "通知权限"
   - "SmartNotificationManager"
   ```

---

## 📝 报告问题时请提供

如果仍然无法解决，请提供：

1. Xcode 控制台的完整日志（特别是带 🔔 的日志）
2. 通知权限状态（0/1/2）
3. 系统设置截图（设置 → HChat → 通知）
4. 测试的消息类型（普通/mention/私聊）
5. 设备型号和 iOS 版本

---

**记住：@mention 消息的优先级最高，如果连这个都收不到，那肯定是权限或系统设置的问题！** 🎯

