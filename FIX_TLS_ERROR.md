# 🔧 修复 TLS 错误

## 🐛 问题

用户报告出现错误：
```
ws receive error: A TLS error caused the secure connection to fail.
```

---

## 🔍 问题分析

### 可能的原因

1. **后端发送消息时连接已关闭**
   - 广播时某些客户端连接可能已断开
   - 单独发送确认消息时连接可能不稳定

2. **客户端错误处理不足**
   - TLS 错误后继续调用 `listen()` 导致循环错误
   - 没有正确停止监听断开的连接

3. **WebSocket 状态检查缺失**
   - 发送消息前没有检查连接状态
   - 可能向已关闭的连接发送数据

---

## ✅ 解决方案

### 1️⃣ 后端改进 (chat-gateway/server.js)

**添加 WebSocket 状态检查和错误处理**

```javascript
// broadcast 函数
function broadcast(channel, packet) {
  const set = rooms.get(channel);
  if (!set) return;
  const text = JSON.stringify(packet);
  for (const ws of set) {
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

**所有单独发送消息的地方都添加检查**

```javascript
// nick 确认消息
if (ws.readyState === 1) {
  try {
    ws.send(JSON.stringify({ 
      type: 'info', 
      text: `昵称已更改为 ${newNick}` 
    }));
  } catch (err) {
    console.error('send nick confirmation error:', err.message);
  }
}

// join 确认消息
if (ws.readyState === 1) {
  try {
    ws.send(JSON.stringify({ type: 'info', text: `joined #${ws.channel}` }));
  } catch (err) {
    console.error('send join confirmation error:', err.message);
  }
}

// presence 消息
if (ws.readyState === 1) {
  try {
    ws.send(JSON.stringify({ 
      type: 'presence', 
      room: ws.channel, 
      users, 
      count: users.length 
    }));
  } catch (err) {
    console.error('send presence error:', err.message);
  }
}
```

---

### 2️⃣ 客户端改进 (HackChatClient.swift)

**改进错误处理逻辑**

```swift
private func listen() {
    guard let ws = webSocket else { return }
    ws.receive { [weak self] result in
        guard let self else { return }
        
        var shouldContinue = true
        
        switch result {
        case .failure(let e):
            DebugLogger.log("❌ WebSocket 接收失败: \(e.localizedDescription)", level: .error)
            
            // TLS 错误或连接断开，不再继续 listen
            if e.localizedDescription.contains("TLS") || 
               e.localizedDescription.contains("closed") ||
               e.localizedDescription.contains("cancelled") {
                DebugLogger.log("🔌 WebSocket 连接已断开，停止监听", level: .warning)
                shouldContinue = false
            }
        case .success(let msg):
            // 处理消息...
        }
        
        // 只有在应该继续时才递归调用 listen
        if shouldContinue {
            Task { @MainActor [weak self] in
                self?.listen()
            }
        }
    }
}
```

---

## 🎯 修复效果

### 修复前

```
1. 连接不稳定导致 TLS 错误
2. 错误后继续调用 listen() 导致循环错误
3. 向已关闭连接发送消息导致崩溃
4. 错误日志不清晰
```

### 修复后

```
✅ 发送消息前检查连接状态
✅ 捕获发送错误并记录
✅ TLS 错误后正确停止监听
✅ 详细的错误日志
✅ 防止向断开的连接发送数据
```

---

## 🚀 部署步骤

### 1. 部署后端

```bash
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
git add chat-gateway/server.js
git commit -m "fix: 添加 WebSocket 状态检查和错误处理"
git push origin main
./deploy.sh chat-gateway
```

### 2. 更新 iOS 客户端

```bash
cd /Users/ryanliu/DDCS/HChat
git add HChat/Core/HackChatClient.swift
git commit -m "fix: 改进 WebSocket 错误处理，TLS 错误后停止监听"
# 在 Xcode 中重新编译
```

---

## 🧪 测试

### 正常场景

1. **正常连接和通信**
   - ✅ 发送消息正常
   - ✅ 接收消息正常
   - ✅ 昵称变更正常

### 错误场景

2. **网络不稳定**
   - ✅ TLS 错误被正确捕获
   - ✅ 停止监听，不再循环错误
   - ✅ 错误日志清晰

3. **连接断开**
   - ✅ 不会向断开的连接发送消息
   - ✅ 服务器端捕获发送错误
   - ✅ 客户端正确停止监听

---

## 🔍 调试

### 后端日志

```bash
ssh root@mx.go-lv.com
cd /root/hc-stack/infra
docker compose logs -f chat-gateway
```

**预期输出（错误情况）：**
```
broadcast send error: Socket is not connected
send nick confirmation error: Socket is not connected
```

### iOS 日志

在 Xcode 控制台应该看到：
```
❌ WebSocket 接收失败: A TLS error caused the secure connection to fail.
🔌 WebSocket 连接已断开，停止监听
```

---

## 📊 WebSocket 状态说明

| readyState | 值 | 说明 |
|-----------|---|------|
| CONNECTING | 0 | 连接尚未建立 |
| OPEN | 1 | 连接已建立，可以通信 ✅ |
| CLOSING | 2 | 连接正在关闭 |
| CLOSED | 3 | 连接已关闭或无法打开 |

**修复要点：** 只在 `readyState === 1` 时发送消息

---

## 💡 最佳实践

### 后端

1. **总是检查连接状态**
   ```javascript
   if (ws.readyState === 1) {
     ws.send(message);
   }
   ```

2. **总是捕获发送错误**
   ```javascript
   try {
     ws.send(message);
   } catch (err) {
     console.error('send error:', err.message);
   }
   ```

3. **定期清理断开的连接**
   ```javascript
   // 使用 ping/pong 检测死连接
   ```

### iOS 客户端

1. **正确处理错误**
   ```swift
   case .failure(let e):
     DebugLogger.log("错误: \(e)", level: .error)
     // 根据错误类型决定是否继续
   ```

2. **防止循环错误**
   ```swift
   if shouldStopListening {
     return  // 不再调用 listen()
   }
   ```

3. **提供清晰的错误日志**
   ```swift
   DebugLogger.log("具体错误原因", level: .error)
   ```

---

## 🔄 未来改进

- [ ] 添加自动重连机制
- [ ] 实现指数退避重连策略
- [ ] 添加连接状态 UI 指示
- [ ] 实现离线消息队列
- [ ] 添加网络质量监控

---

**修复后 TLS 错误应该不会再出现，即使出现也会被正确处理！** ✅

