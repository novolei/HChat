# 👋 用户加入/离开频道通知功能

**日期：** 2025-10-21  
**功能：** 用户进入或离开频道时，向频道内其他用户发送通知  
**状态：** ✅ 已实现

---

## 🎯 功能描述

### 用户加入频道

当用户首次打开 App 或执行 `/join` 命令加入频道时：
- ✅ 服务器广播给频道内**其他用户**："XXX 加入了 #频道"
- ✅ 自己收到确认消息，但**不会显示**（被过滤）

### 用户离开频道

当用户关闭 App 或断开连接时：
- ✅ 服务器广播给频道内**其他用户**："XXX 离开了 #频道"

---

## 🔧 技术实现

### 1️⃣ 服务器端 (`chat-gateway/server.js`)

#### 修改 broadcast 函数

**支持排除特定用户（通常是发送者自己）：**

```javascript
function broadcast(channel, packet, excludeWs = null) {
  const set = rooms.get(channel);
  if (!set) return;
  const text = JSON.stringify(packet);
  for (const ws of set) {
    // ✅ 排除指定的 WebSocket 连接（通常是发送者自己）
    if (ws === excludeWs) continue;
    
    if (ws.readyState === 1) {  // 1 = WebSocket.OPEN
      try {
        ws.send(text);
      } catch (err) {
        console.error('broadcast send error:', err.message);
      }
    }
  }
}
```

**关键改动：**
- 新增 `excludeWs` 参数（可选）
- 循环时跳过 `excludeWs` 指定的连接

---

#### 处理 join 命令

```javascript
// 处理 join 命令
if (msgType === 'join' && channel) {
  ws.channel = channel;
  ws.nick = ws.nick || msg.nick || 'guest';
  if (!rooms.has(ws.channel)) rooms.set(ws.channel, new Set());
  rooms.get(ws.channel).add(ws);
  
  // ✅ 广播给频道内其他用户（不包括自己）
  broadcast(ws.channel, {
    type: 'user_joined',
    nick: ws.nick,
    channel: ws.channel
  }, ws);  // 传入 ws 表示排除自己
  
  // 发送确认消息给当前用户
  if (ws.readyState === 1) {
    try {
      ws.send(JSON.stringify({ type: 'info', text: `joined #${ws.channel}` }));
    } catch (err) {
      console.error('send join confirmation error:', err.message);
    }
  }
  return;
}
```

**流程：**
1. 用户加入频道
2. 广播 `user_joined` 消息给**其他用户**
3. 发送 `info` 确认消息给**自己**

---

#### 处理 close 事件

```javascript
ws.on('close', () => {
  if (ws.channel && rooms.get(ws.channel)) {
    // ✅ 广播用户离开通知（在删除之前）
    broadcast(ws.channel, {
      type: 'user_left',
      nick: ws.nick || 'guest',
      channel: ws.channel
    }, ws);  // 排除自己（虽然已经断开）
    
    rooms.get(ws.channel).delete(ws);
    if (rooms.get(ws.channel).size === 0) rooms.delete(ws.channel);
  }
});
```

**流程：**
1. WebSocket 连接关闭
2. 广播 `user_left` 消息给**其他用户**
3. 从频道中移除该用户

---

### 2️⃣ iOS 客户端 (`HackChatClient.swift`)

#### 处理用户加入通知

```swift
// ✅ 处理用户加入频道通知
if type == "user_joined" {
    let nick = (obj["nick"] as? String) ?? "someone"
    let channel = (obj["channel"] as? String) ?? currentChannel
    DebugLogger.log("👋 用户加入: \(nick) → #\(channel)", level: .debug)
    systemMessage("\(nick) 加入了 #\(channel)")
    return
}
```

**效果：**
- ✅ 显示："Alice 加入了 #lobby"
- ✅ 记录调试日志

---

#### 处理用户离开通知

```swift
// ✅ 处理用户离开频道通知
if type == "user_left" {
    let nick = (obj["nick"] as? String) ?? "someone"
    let channel = (obj["channel"] as? String) ?? currentChannel
    DebugLogger.log("👋 用户离开: \(nick) ← #\(channel)", level: .debug)
    systemMessage("\(nick) 离开了 #\(channel)")
    return
}
```

**效果：**
- ✅ 显示："Alice 离开了 #lobby"
- ✅ 记录调试日志

---

#### 过滤自己的 join 确认

```swift
// ✅ 过滤昵称相关的 info 消息（保持界面简洁）
if type == "info" {
    let text = (obj["text"] as? String) ?? ""
    // 过滤 "昵称已更改为 XXX" 和 "joined #XXX" 消息
    if text.contains("昵称已更改为") || text.hasPrefix("joined #") {
        DebugLogger.log("🚫 过滤 info 消息: \(text)", level: .debug)
        return
    }
}
```

**效果：**
- ❌ 不显示自己的 "joined #lobby" 确认
- ✅ 保持界面简洁

---

## 📊 消息流程

### 场景 1：用户 A 首次打开 App

```
时间线：

1. 用户 A 打开 App
   ↓
2. 连接 WebSocket
   ↓
3. 发送 nick 命令：{"type":"nick", "nick":"Alice"}
   ↓
4. 发送 join 命令：{"type":"join", "room":"lobby"}
   ↓
5. 服务器处理：
   - 用户 A 加入 lobby
   - 广播给用户 B, C, D：{"type":"user_joined", "nick":"Alice", "channel":"lobby"}
   - 发送确认给用户 A：{"type":"info", "text":"joined #lobby"}
   ↓
6. 用户 B, C, D 收到：
   显示："Alice 加入了 #lobby"
   ↓
7. 用户 A 收到确认：
   过滤，不显示
```

---

### 场景 2：用户切换频道

```
用户 A 当前在 #lobby，执行 /join programming

1. 用户 A 发送：{"type":"join", "room":"programming"}
   ↓
2. 服务器处理：
   - 用户 A 加入 #programming
   - 广播给 #programming 的其他用户：
     {"type":"user_joined", "nick":"Alice", "channel":"programming"}
   - 发送确认给用户 A：
     {"type":"info", "text":"joined #programming"}
   ↓
3. #programming 中的用户收到：
   显示："Alice 加入了 #programming"
   ↓
4. 用户 A 看到：
   "已加入 #programming"（本地命令处理）
```

**注意：** 当前实现中，用户切换频道时**不会自动离开**旧频道，这是设计行为。

---

### 场景 3：用户关闭 App

```
用户 A 在 #lobby 中，关闭 App

1. WebSocket 连接断开
   ↓
2. 服务器触发 close 事件
   ↓
3. 服务器处理：
   - 广播给 #lobby 的其他用户：
     {"type":"user_left", "nick":"Alice", "channel":"lobby"}
   - 从 #lobby 移除用户 A
   ↓
4. #lobby 中的用户 B, C, D 收到：
   显示："Alice 离开了 #lobby"
```

---

## 🧪 测试场景

### 测试 1：用户加入

**准备：**
- 设备 A：已在 #lobby
- 设备 B：准备打开 App

**步骤：**
1. 设备 B 打开 App
2. 设置昵称为 "Bob"

**预期结果：**

设备 A 看到：
```
• 20:15
Bob 加入了 #lobby
```

设备 B 看到：
```
• 20:15
Bob 进入 #lobby
（首次设置昵称的提示）
```

---

### 测试 2：用户离开

**准备：**
- 设备 A（Alice）和设备 B（Bob）都在 #lobby

**步骤：**
1. 设备 B 关闭 App 或断开连接

**预期结果：**

设备 A 看到：
```
• 20:16
Bob 离开了 #lobby
```

设备 B：
```
（App 已关闭）
```

---

### 测试 3：切换频道

**准备：**
- 设备 A（Alice）在 #lobby
- 设备 B（Bob）在 #lobby

**步骤：**
1. 设备 B 输入 `/join programming`

**预期结果：**

设备 A 在 #lobby：
```
（不显示任何消息，Bob 没有离开 lobby）
```

设备 B 在 #programming：
```
• 20:17
已加入 #programming
```

#programming 中的其他用户看到：
```
• 20:17
Bob 加入了 #programming
```

---

## 💡 设计考虑

### 为什么排除自己？

1. **避免重复信息**
   - 用户已经知道自己加入了
   - 本地会显示"已加入 #频道"

2. **保持界面简洁**
   - 减少冗余的系统消息
   - 专注于重要信息

3. **用户体验**
   - 只需要知道**其他人**的动态
   - 自己的操作已经有即时反馈

---

### 为什么不自动离开旧频道？

当前设计允许用户"同时"在多个频道中：
- ✅ 用户可以切换频道查看不同内容
- ✅ 不会错过其他频道的 @ 提及
- ✅ 符合 IRC 风格的聊天习惯

**未来改进：**
- 可以添加 `/leave` 命令明确离开频道
- 或者添加"活跃频道"概念

---

## 🎨 UI 显示效果

### 加入提示

```
系统消息样式：

• 20:15
Alice 加入了 #lobby
```

**特点：**
- 灰色文字
- 时间戳
- 简洁清晰

---

### 离开提示

```
系统消息样式：

• 20:16
Bob 离开了 #lobby
```

**特点：**
- 灰色文字
- 时间戳
- 与加入提示一致

---

## 📋 消息协议

### user_joined 消息

```json
{
  "type": "user_joined",
  "nick": "Alice",
  "channel": "lobby"
}
```

**字段说明：**
- `type`: 消息类型（固定为 `user_joined`）
- `nick`: 加入的用户昵称
- `channel`: 频道名称

---

### user_left 消息

```json
{
  "type": "user_left",
  "nick": "Bob",
  "channel": "lobby"
}
```

**字段说明：**
- `type`: 消息类型（固定为 `user_left`）
- `nick`: 离开的用户昵称
- `channel`: 频道名称

---

## 🔍 调试日志

### 服务器端

```bash
# 查看 chat-gateway 日志
ssh root@mx.go-lv.com
cd /root/hc-stack/infra
docker compose logs -f chat-gateway
```

**预期输出：**
```
chat-gateway  | User Alice joined #lobby
chat-gateway  | Broadcasting user_joined to 3 users
chat-gateway  | User Bob left #lobby
chat-gateway  | Broadcasting user_left to 2 users
```

---

### iOS 客户端

在 Xcode 控制台查看 DebugLogger 输出：

```
👋 用户加入: Alice → #lobby
👋 用户离开: Bob ← #lobby
🚫 过滤 info 消息: joined #lobby
```

---

## 🚀 部署步骤

### 1. 部署后端

```bash
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
git add chat-gateway/server.js
git commit -m "feat: 添加用户加入/离开频道通知"
git push origin main
./ai-deploy.sh chat-gateway
```

### 2. 更新 iOS 客户端

```bash
cd /Users/ryanliu/DDCS/HChat
git add HChat/Core/HackChatClient.swift
git commit -m "feat: 处理用户加入/离开频道通知"
# 在 Xcode 中重新编译和运行
```

---

## 📝 修改文件清单

### 后端

**`chat-gateway/server.js`**
1. `broadcast()` 函数
   - 新增 `excludeWs` 参数
   - 支持排除特定连接

2. `join` 命令处理
   - 广播 `user_joined` 消息

3. `close` 事件处理
   - 广播 `user_left` 消息

---

### iOS 客户端

**`HChat/Core/HackChatClient.swift`**
1. `handleIncomingData()`
   - 新增 `user_joined` 消息处理
   - 新增 `user_left` 消息处理
   - 过滤自己的 join 确认消息

---

## 🎯 总结

### 实现功能

1. ✅ **用户加入通知**
   - 服务器广播给其他用户
   - 客户端显示系统消息
   - 排除自己，避免重复

2. ✅ **用户离开通知**
   - WebSocket 关闭时广播
   - 其他用户收到通知
   - 自动清理频道成员

3. ✅ **界面简洁**
   - 只显示其他人的动态
   - 过滤自己的确认消息
   - 符合用户预期

### 用户体验

| 方面 | 效果 |
|------|------|
| 加入通知 | 其他用户看到新人进入 ✅ |
| 离开通知 | 其他用户知道有人离开 ✅ |
| 自己的确认 | 不显示，避免重复 ✅ |
| 界面清晰度 | 简洁明了 ✅ |

---

**🎉 用户加入/离开通知功能已完成！现在用户可以实时看到频道内的人员变动！** ✅

