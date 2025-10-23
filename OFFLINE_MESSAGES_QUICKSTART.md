# 📬 离线消息快速实施指南

## 当前问题

App 完全退出后，其他用户发来的消息会丢失。

## 快速解决方案（1-2 小时）

### 阶段 1：内存队列（立即可用）

#### 后端改造

**文件**: `HCChatBackEnd/chat-gateway/src/handlers/messageHandler.js`

```javascript
// 添加内存队列
const offlineQueue = new Map(); // userId -> messages[]

function handleChatMessage(ws, message) {
  const { channel, nick, text } = message;
  
  // 1. 广播给在线用户
  const onlineClients = getChannelClients(channel);
  onlineClients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({
        cmd: 'chat',
        nick,
        text,
        timestamp: Date.now()
      }));
    }
  });
  
  // 2. 检查是否有离线用户
  const allChannelUsers = getChannelUserList(channel); // 从数据库或缓存获取
  const offlineUsers = allChannelUsers.filter(user => 
    !isUserOnline(user, channel)
  );
  
  // 3. 为离线用户入队消息
  offlineUsers.forEach(userId => {
    if (!offlineQueue.has(userId)) {
      offlineQueue.set(userId, []);
    }
    
    offlineQueue.get(userId).push({
      channel,
      sender: nick,
      text, // E2EE 密文
      timestamp: Date.now()
    });
    
    // 限制队列大小（防止内存溢出）
    const queue = offlineQueue.get(userId);
    if (queue.length > 1000) {
      queue.shift(); // 删除最老的消息
    }
  });
}

function handleUserOnline(ws, userId, channel) {
  // 检查是否有离线消息
  if (offlineQueue.has(userId)) {
    const messages = offlineQueue.get(userId);
    
    // 推送离线消息
    ws.send(JSON.stringify({
      cmd: 'offline_messages',
      messages: messages.filter(msg => msg.channel === channel)
    }));
    
    // 清除已推送的消息
    offlineQueue.delete(userId);
  }
}
```

#### iOS 端改造

**文件**: `HChat/Core/Networking/MessageHandler.swift`

```swift
func handleMessage(_ data: Data) {
    // ... 解析 ...
    
    let type = (obj["type"] as? String) ?? "message"
    
    switch type {
    case "offline_messages":
        handleOfflineMessages(obj)
    
    // ... 其他 case ...
    }
}

private func handleOfflineMessages(_ obj: [String: Any]) {
    guard let messages = obj["messages"] as? [[String: Any]] else { return }
    
    DebugLogger.log("📬 收到 \(messages.count) 条离线消息", level: .info)
    
    // 批量处理离线消息
    for msgObj in messages {
        // 使用现有的消息处理逻辑
        handleChatMessage(msgObj, state: state)
    }
    
    // 显示 Toast 提示
    Task { @MainActor in
        // TODO: 显示 "收到 X 条新消息" 的提示
    }
}
```

### 优点

- ✅ 1-2 小时即可完成
- ✅ 不需要数据库
- ✅ 支持短时间离线（几小时内）
- ✅ 与 E2EE 完全兼容

### 缺点

- ❌ 服务器重启消息丢失
- ❌ 不支持长时间离线（>24小时）

### 测试场景

1. 用户 A 打开 App 并连接
2. 用户 B 杀掉 App（完全退出）
3. 用户 A 发送消息给频道
4. 用户 B 重新打开 App
5. 验证：用户 B 收到离线期间的消息 ✅

---

## 下一步：Redis 持久化（1-2 天）

### docker-compose.yml

```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes

volumes:
  redis-data:
```

### 使用 Redis 存储

```javascript
const redis = require('redis');
const client = redis.createClient({ url: 'redis://redis:6379' });

// 存储离线消息
async function queueOfflineMessage(userId, message) {
  const key = `offline:${userId}`;
  await client.lpush(key, JSON.stringify(message));
  await client.expire(key, 86400 * 7); // 7天过期
}

// 获取离线消息
async function getOfflineMessages(userId) {
  const key = `offline:${userId}`;
  const messages = await client.lrange(key, 0, -1);
  await client.del(key); // 获取后删除
  return messages.map(msg => JSON.parse(msg));
}
```

### 优点

- ✅ 服务器重启不丢消息
- ✅ 支持 7 天内离线消息
- ✅ 性能好

---

## 最终目标：完整 IM 系统

### 功能清单

- [ ] 离线消息（内存队列）← 现在
- [ ] 离线消息（Redis 持久化）← 本周
- [ ] 历史消息（PostgreSQL）← 本月
- [ ] 推送通知（APNs）← 本月
- [ ] 多端同步 ← 未来
- [ ] 消息撤回 ← 未来
- [ ] 消息转发 ← 未来

---

## 要开始实现吗？

我可以帮你：

1. ✅ 修改后端代码（chat-gateway）
2. ✅ 修改 iOS 代码（MessageHandler）
3. ✅ 测试离线消息功能
4. ✅ 部署到服务器

预计时间：1-2 小时

准备好了就告诉我！
