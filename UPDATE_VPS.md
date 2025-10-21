# 🔄 更新 VPS 上的 chat-gateway

## 🐛 问题已修复

修复了**双重消息**问题！服务器现在会转发客户端的消息 ID，让去重逻辑正常工作。

---

## 📋 在 VPS 上执行以下命令

```bash
# 1. SSH 登录到 VPS
ssh root@mx.go-lv.com

# 2. 进入项目目录
cd /root/hc-stack

# 3. 拉取最新代码
git pull origin main

# 4. 重启 chat-gateway 服务
docker compose restart chat-gateway

# 5. 查看日志确认启动成功
docker compose logs -f chat-gateway
```

---

## ✅ 验证修复

重启后，在 iOS App 中：

1. 发送一条测试消息
2. **预期结果**：只显示**一条**消息（而不是两条）
3. 检查 Xcode 控制台日志，应该看到：
   ```
   📤 本地添加消息 (Local Echo) - ID: xxx
   📥 收到消息 - ID: xxx (相同的 ID)
   ✅ 去重成功 - 忽略自己发送的消息 ID: xxx
   ```

---

## 🔍 如果还有问题

查看详细日志：

```bash
# iOS 客户端日志（Xcode 控制台）
# 应该看到消息 ID 和去重日志

# 服务器日志
docker compose logs chat-gateway | tail -50
```

---

## 🎯 修复内容

### 服务器端 (chat-gateway/server.js)

**修复前：**
```javascript
broadcast(ws.channel, { 
  cmd: 'chat', 
  nick: ws.nick, 
  text: msg.text 
  // ❌ 没有 id！
});
```

**修复后：**
```javascript
broadcast(ws.channel, { 
  type: 'message',
  channel: ws.channel,
  nick: ws.nick, 
  text: msg.text,
  id: msg.id  // ✅ 转发客户端 ID
});
```

### 客户端 (HackChatClient.swift)

添加了详细的调试日志，可以追踪消息流转。

---

**更新后应该就不会再看到两条重复消息了！** 🎉

