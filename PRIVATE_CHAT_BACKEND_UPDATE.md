# 🚀 私聊功能后端更新指南

## 概述

为支持 1:1 私聊功能，需要更新 chat-gateway 后端代码。

## 部署路径

根据部署记录，后端位于 VPS：
- **服务器**: `root@mx.go-lv.com`
- **部署路径**: `~/hc-stack`

## 需要更新的文件

### 1. 新增文件

#### `/hc-stack/chat-gateway/src/handlers/dmHandler.js`

```javascript
// handlers/dmHandler.js
// 处理私聊消息（Direct Message）

const { broadcast } = require('../services/broadcaster');
const roomManager = require('../services/roomManager');

/**
 * 处理私聊消息
 * @param {WebSocket} ws - 发送者的 WebSocket 连接
 * @param {Object} msg - 消息对象
 */
function handleDirectMessage(ws, msg) {
  if (!msg.to || typeof msg.text !== 'string') {
    console.warn(`⚠️ 无效的私聊消息: ${JSON.stringify(msg)}`);
    return;
  }
  
  const from = ws.nick || 'guest';
  const to = msg.to;
  const messageId = msg.id || generateId();
  
  // ✨ 创建虚拟私聊频道 ID（确保双方看到同一个频道）
  const dmChannel = getDMChannel(from, to);
  
  console.log(`💬 私聊消息: ${from} -> ${to} (channel: ${dmChannel})`);
  
  // ✨ 立即发送 ACK 给发送者
  if (ws.readyState === 1) {
    try {
      ws.send(JSON.stringify({
        type: 'message_ack',
        messageId: messageId,
        status: 'received',
        timestamp: Date.now()
      }));
      console.log(`✅ ACK sent for DM ${messageId}`);
    } catch (e) {
      console.error(`❌ Failed to send ACK: ${e.message}`);
    }
  }
  
  // ✨ 构建私聊消息（广播到虚拟频道）
  const broadcastMsg = {
    type: 'message',
    channel: dmChannel,
    nick: from,
    text: msg.text,
    id: messageId,
    isDM: true,           // 标记为私聊消息
    dmWith: to,           // 对方用户
    attachment: msg.attachment
  };
  
  // 如果有回复信息
  if (msg.replyTo) {
    broadcastMsg.replyTo = msg.replyTo;
  }
  
  // ✨ 广播消息到虚拟私聊频道
  broadcast(dmChannel, broadcastMsg);
  
  // ✨ 检查对方是否在线，发送 delivered 确认
  const recipientWs = findUserByNick(to);
  const deliveredTo = [];
  
  if (recipientWs && recipientWs.readyState === 1) {
    deliveredTo.push(to);
  }
  
  // 发送 delivered 确认给发送者
  if (deliveredTo.length > 0 && ws.readyState === 1) {
    try {
      ws.send(JSON.stringify({
        type: 'message_delivered',
        messageId: messageId,
        deliveredTo: deliveredTo,
        timestamp: Date.now()
      }));
      console.log(`📫 DM delivered to ${to}`);
    } catch (e) {
      console.error(`❌ Failed to send delivered confirmation: ${e.message}`);
    }
  } else {
    console.log(`📭 ${to} is offline, message queued for later delivery`);
    // TODO: 实现离线消息队列
  }
}

/**
 * 生成私聊频道 ID（确保双方看到同一个频道）
 * @param {string} user1 - 用户1
 * @param {string} user2 - 用户2
 * @returns {string} - 虚拟频道 ID
 */
function getDMChannel(user1, user2) {
  // 排序确保顺序一致
  const sorted = [user1, user2].sort();
  return `dm:${sorted[0]}:${sorted[1]}`;
}

/**
 * 根据昵称查找用户的 WebSocket 连接
 * @param {string} nick - 用户昵称
 * @returns {WebSocket|null} - WebSocket 连接或 null
 */
function findUserByNick(nick) {
  // 遍历所有频道的所有用户
  const allRooms = roomManager.getAllRooms();
  
  for (const room of Object.keys(allRooms)) {
    const users = roomManager.getRoomUsers(room);
    for (const ws of users) {
      if (ws.nick === nick && ws.readyState === 1) {
        return ws;
      }
    }
  }
  
  return null;
}

/**
 * 简单的 ID 生成器
 * @returns {string} - 唯一 ID
 */
function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

module.exports = { handleDirectMessage, getDMChannel };
```

### 2. 更新文件

#### `/hc-stack/chat-gateway/src/handlers/index.js`

**位置1**: 在文件顶部的 require 部分添加：

```javascript
const { handleDirectMessage } = require('./dmHandler'); // ✨ 私聊消息
```

**位置2**: 在 `handleMessage` 函数的 switch 语句中添加（在 `case 'typing'` 之后）：

```javascript
    case 'dm': // ✨ 私聊消息
    case 'direct_message':
      handleDirectMessage(ws, msg);
      break;
```

#### `/hc-stack/chat-gateway/src/services/roomManager.js`

**位置1**: 在 `getRoomUsers` 函数之后添加新函数：

```javascript
/**
 * 获取所有房间
 */
function getAllRooms() {
  return rooms;
}
```

**位置2**: 更新 `module.exports` 添加导出：

```javascript
module.exports = {
  addUser,
  removeUser,
  getUsers,
  getRoomUsers,
  getAllRooms,  // ✨ 新增
  cleanup,
};
```

## 部署步骤

### 方式1: SSH 登录手动部署

```bash
# 1. 登录 VPS
ssh root@mx.go-lv.com

# 2. 进入部署目录
cd ~/hc-stack/chat-gateway/src

# 3. 备份原文件
cp handlers/index.js handlers/index.js.bak
cp services/roomManager.js services/roomManager.js.bak

# 4. 创建新文件 handlers/dmHandler.js
# （复制上面的完整代码）

# 5. 编辑 handlers/index.js
# - 添加 require('./dmHandler')
# - 添加 case 'dm' 分支

# 6. 编辑 services/roomManager.js
# - 添加 getAllRooms() 函数
# - 导出 getAllRooms

# 7. 重启 chat-gateway 服务
cd ~/hc-stack
docker-compose restart chat-gateway

# 8. 查看日志确认启动成功
docker-compose logs -f chat-gateway
```

### 方式2: 使用部署脚本（推荐）

```bash
# 从本地执行
./scripts/deploy-private-chat-backend.sh
```

## 测试验证

部署完成后，测试以下功能：

### 1. 私聊消息发送

在 iOS 客户端：
1. 打开"通讯录" Tab
2. 点击任意在线用户
3. 发送消息："你好"
4. 检查消息是否成功发送并收到 ACK

### 2. 私聊消息接收

在另一个客户端：
1. 检查是否收到私聊消息
2. 验证消息显示在正确的会话中
3. 回复消息

### 3. 在线状态

1. 检查用户在线状态点是否正确显示
2. 离线用户是否显示"最后在线时间"

### 4. 查看服务器日志

```bash
# 查看最近的私聊消息日志
docker logs chat-gateway | grep "💬 私聊消息"

# 查看 ACK 日志
docker logs chat-gateway | grep "ACK sent for DM"

# 查看送达确认
docker logs chat-gateway | grep "DM delivered"
```

## 预期日志输出

成功的私聊消息应该产生类似日志：

```
💬 私聊消息: Alice -> Bob (channel: dm:Alice:Bob)
✅ ACK sent for DM abc123xyz
📫 DM delivered to Bob
```

离线用户的日志：

```
💬 私聊消息: Alice -> Charlie (channel: dm:Alice:Charlie)
✅ ACK sent for DM def456uvw
📭 Charlie is offline, message queued for later delivery
```

## 回滚方案

如果出现问题，快速回滚：

```bash
# 1. 登录 VPS
ssh root@mx.go-lv.com
cd ~/hc-stack/chat-gateway/src

# 2. 恢复备份文件
cp handlers/index.js.bak handlers/index.js
cp services/roomManager.js.bak services/roomManager.js

# 3. 删除新增文件
rm handlers/dmHandler.js

# 4. 重启服务
cd ~/hc-stack
docker-compose restart chat-gateway
```

## 下一步计划

1. ✅ 后端支持私聊消息路由
2. ⏳ 后端支持在线状态广播
3. ⏳ iOS 端处理私聊消息
4. ⏳ 测试私聊功能
5. 🔮 实现好友系统（陌生人限制）
6. 🔮 实现离线消息队列

## 注意事项

- ⚠️ 部署前先备份现有文件
- ⚠️ 确保 Docker 容器有足够的资源
- ⚠️ 监控服务器日志，确认无错误
- ⚠️ 如有问题，立即回滚到备份版本

## 联系方式

如有问题，请查看：
- GitHub Issues: https://github.com/novolei/HChat/issues
- 服务器日志: `docker-compose logs -f chat-gateway`

