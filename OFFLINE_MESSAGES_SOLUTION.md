# 📬 离线消息处理方案

## 问题描述

当用户的 App 完全退出（杀掉进程）或长时间在后台时，其他用户发来的消息该如何处理？

## 当前架构分析

### 现有系统

```
iOS App (WebSocket) ←→ chat-gateway (Node.js) ←→ 其他客户端
```

**特点**：
- ✅ 实时性好：WebSocket 即时推送
- ✅ 零知识架构：服务器不存储明文
- ❌ **无消息持久化**：服务器不保存历史消息
- ❌ **无离线队列**：用户离线时消息丢失

### 问题场景

#### 场景 1：App 完全退出

```
Alice 发送消息给 Bob
    ↓
chat-gateway 检查 Bob 是否在线
    ↓
Bob 不在线（WebSocket 断开）
    ↓
消息丢失 ❌
```

#### 场景 2：App 在后台太久

```
Bob 的 App 在后台超过 30 分钟
    ↓
iOS 杀掉进程（省电）
    ↓
WebSocket 断开
    ↓
Alice 发送消息
    ↓
消息丢失 ❌
```

## 解决方案对比

### 方案 1：服务器端消息队列（推荐）⭐

**架构**：
```
iOS App ←→ chat-gateway ←→ message-queue (Redis/DB) ←→ message-service
```

**优点**：
- ✅ 可靠性高：消息不会丢失
- ✅ 支持历史记录：可以查看离线期间的消息
- ✅ 支持多端同步：Web/Android/iOS 都能收到
- ✅ 可以实现已读回执、消息撤回等高级功能

**缺点**：
- ❌ 需要后端改造（添加数据库）
- ❌ E2EE 消息存储需要特殊处理（存密文）
- ❌ 增加服务器成本

**实现步骤**：

#### 1. 后端改造

```javascript
// chat-gateway/src/handlers/messageHandler.js

async function handleChatMessage(ws, message) {
  const { channel, nick, text } = message;
  
  // 1. 广播给在线用户
  broadcastToChannel(channel, {
    cmd: 'chat',
    nick,
    text,
    timestamp: Date.now()
  });
  
  // 2. 保存到消息队列（用于离线用户）
  await saveMessageToQueue({
    channel,
    sender: nick,
    text, // E2EE 密文
    timestamp: Date.now()
  });
}

// 当用户上线时
function handleUserOnline(ws, userId, channel) {
  // 1. 拉取离线消息
  const offlineMessages = await getOfflineMessages(userId, channel);
  
  // 2. 推送给客户端
  ws.send(JSON.stringify({
    cmd: 'offline_messages',
    messages: offlineMessages
  }));
  
  // 3. 清除已推送的离线消息
  await clearOfflineMessages(userId, channel);
}
```

#### 2. iOS 端改造

```swift
// MessageHandler.swift

func handleMessage(_ data: Data) {
    // ... 解析消息 ...
    
    switch type {
    case "offline_messages":
        // 处理离线消息批量推送
        handleOfflineMessages(obj)
    
    case "chat":
        // 正常处理实时消息
        handleChatMessage(obj, state: state)
    
    // ...
    }
}

private func handleOfflineMessages(_ obj: [String: Any]) {
    guard let messages = obj["messages"] as? [[String: Any]] else { return }
    
    for msgObj in messages {
        // 解密并添加到消息列表
        handleChatMessage(msgObj, state: state)
    }
    
    DebugLogger.log("📬 收到 \(messages.count) 条离线消息", level: .info)
}
```

---

### 方案 2：Apple Push Notification (APNs) + 服务器队列 ⭐⭐

**架构**：
```
iOS App (离线)
    ↓
APNs 推送通知
    ↓
用户点击通知打开 App
    ↓
App 连接 WebSocket
    ↓
拉取离线消息
```

**优点**：
- ✅ 用户体验最好：即使 App 退出也能收到通知
- ✅ 符合用户预期：和微信、WhatsApp 一样
- ✅ 可以显示消息内容（需要解密）

**缺点**：
- ❌ 需要 Apple Developer 账号（$99/年）
- ❌ 需要配置 APNs 证书
- ❌ 后端需要集成 APNs SDK
- ❌ E2EE 消息无法在通知中显示明文（服务器没有密钥）

**实现步骤**：

#### 1. iOS 注册 APNs

```swift
// HChatApp.swift

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // 注册远程推送
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        if granted {
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }
    
    return true
}

func application(_ application: UIApplication, 
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    
    // 发送 token 到服务器
    client.registerPushToken(token)
}
```

#### 2. 后端推送通知

```javascript
// message-service/src/services/pushNotificationService.js

const apn = require('apn');

async function sendPushNotification(userId, message) {
  const userToken = await getUserPushToken(userId);
  
  const notification = new apn.Notification({
    alert: {
      title: message.sender,
      body: '发来一条新消息' // 不能显示密文
    },
    badge: 1,
    sound: 'default',
    payload: {
      messageId: message.id,
      channel: message.channel
    }
  });
  
  await apnProvider.send(notification, userToken);
}
```

---

### 方案 3：仅客户端本地存储（轻量级）

**架构**：
```
iOS App 本地数据库 (Core Data / Realm)
    ↑
只存储已收到的消息
    ↑
离线期间的消息丢失
```

**优点**：
- ✅ 实现简单：不需要后端改造
- ✅ 隐私性好：数据只在本地

**缺点**：
- ❌ **离线消息仍然丢失**
- ❌ 无法多端同步
- ❌ 换手机后历史消息丢失

**不推荐**：只能解决历史记录问题，不能解决离线消息问题。

---

### 方案 4：混合方案（渐进式实现）⭐⭐⭐

结合多种方案，分阶段实现：

#### 阶段 1：基础离线消息（当前可实现）

1. **后端添加简单的内存队列**：
   ```javascript
   // 用 Map 存储离线消息（重启会丢失）
   const offlineQueue = new Map(); // userId -> messages[]
   ```

2. **用户上线时拉取**：
   ```javascript
   if (offlineQueue.has(userId)) {
     const messages = offlineQueue.get(userId);
     ws.send({ cmd: 'offline_messages', messages });
     offlineQueue.delete(userId);
   }
   ```

3. **优点**：
   - ✅ 快速实现（1-2 小时）
   - ✅ 不需要数据库
   - ✅ 支持短时间离线（<24小时）

4. **缺点**：
   - ❌ 服务器重启消息丢失
   - ❌ 不支持历史记录

#### 阶段 2：持久化队列（Redis）

1. **使用 Redis 存储离线消息**：
   ```javascript
   await redis.lpush(`offline:${userId}:${channel}`, JSON.stringify(message));
   await redis.expire(`offline:${userId}:${channel}`, 86400 * 7); // 7天过期
   ```

2. **优点**：
   - ✅ 服务器重启不丢消息
   - ✅ 性能好
   - ✅ 可以设置过期时间

#### 阶段 3：完整历史记录（PostgreSQL/MongoDB）

1. **所有消息持久化**
2. **支持消息搜索**
3. **支持多端同步**

#### 阶段 4：推送通知（APNs）

1. **集成 Apple Push Notification**
2. **离线时推送通知**
3. **点击通知打开 App 并拉取消息**

---

## 推荐实施方案

### 立即实现（1-2 小时）

**方案 4 - 阶段 1**：内存队列 + 上线拉取

```
chat-gateway 添加离线消息队列
    ↓
用户离线时消息入队
    ↓
用户上线时批量推送
    ↓
iOS 客户端处理 offline_messages
```

**优点**：
- ✅ 快速解决问题
- ✅ 不需要额外组件
- ✅ 支持短时间离线场景（几小时内）

### 中期实现（1-2 天）

**方案 4 - 阶段 2**：Redis 持久化

```
添加 Redis 到 docker-compose.yml
    ↓
chat-gateway 使用 Redis 存储离线消息
    ↓
支持 7 天内的离线消息
```

### 长期实现（1 周）

**方案 4 - 阶段 3 + 4**：完整消息系统

```
PostgreSQL 存储所有消息
    ↓
APNs 推送通知
    ↓
多端同步
    ↓
完整的 IM 功能
```

---

## E2EE 与离线消息的兼容性

### 挑战

离线消息需要服务器存储，但 E2EE 要求服务器不能解密。

### 解决方案

1. **存储密文**：
   ```javascript
   // 服务器存储加密后的消息
   {
     sender: "Alice",
     text: "E2EE:base64encodedciphertext...",
     channel: "ios-dev",
     timestamp: 1234567890
   }
   ```

2. **客户端解密**：
   ```swift
   // iOS 收到离线消息后解密
   let plaintext = e2eeManager.decrypt(ciphertext, channel: channel)
   ```

3. **通知内容**：
   ```javascript
   // APNs 推送通知只显示"有新消息"
   {
     alert: {
       title: "Alice",
       body: "发来一条新消息" // 不显示内容
     }
   }
   ```

---

## 实施建议

### 现在立即做

1. ✅ **实现内存队列**（方案 4 阶段 1）
   - 修改 `chat-gateway` 添加离线消息队列
   - iOS 端添加 `offline_messages` 处理
   - 测试短时间离线场景

### 本周完成

2. ✅ **添加 Redis 持久化**（方案 4 阶段 2）
   - `docker-compose.yml` 添加 Redis 服务
   - 修改 `chat-gateway` 使用 Redis
   - 支持 7 天内离线消息

### 本月完成

3. ✅ **实现推送通知**（方案 4 阶段 4）
   - 申请 Apple Developer 账号
   - 配置 APNs
   - 后端集成推送服务
   - iOS 端注册推送 token

### 长期规划

4. ✅ **完整消息系统**（方案 4 阶段 3）
   - 数据库存储所有消息
   - 消息搜索功能
   - 多端同步
   - 完整的已读回执

---

## 结论

**推荐方案**：方案 4（混合/渐进式）

**理由**：
1. ✅ 可以立即开始实现（内存队列）
2. ✅ 逐步完善功能（Redis → DB → APNs）
3. ✅ 每个阶段都能带来实际价值
4. ✅ 投入产出比合理
5. ✅ 与 E2EE 架构兼容

**下一步**：
1. 我可以帮你实现"方案 4 - 阶段 1"（内存队列）
2. 预计 1-2 小时完成
3. 立即解决短时间离线的问题

要开始实现吗？

