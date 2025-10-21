# 🔄 更新 VPS 上的 chat-gateway

## 🐛 问题已修复

修复了**双重消息**问题！服务器现在会转发客户端的消息 ID，让去重逻辑正常工作。

---

## 🚀 推荐方法：使用自动化部署脚本

**最简单的方式（推荐）：**

```bash
# 在本地 Mac 上
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
./deploy.sh chat-gateway
```

脚本会自动：
- ✅ 检测 VPS 上的本地修改
- ✅ 自动保存并同步到最新代码
- ✅ 重启服务
- ✅ 显示日志

**不会再有 Git 冲突问题！** ✨

---

## 📋 手动方法（备用）

如果需要手动更新，在 VPS 上执行以下命令

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

---

## 🛡️ 如何避免以后出现 Git 冲突

### ✅ 一次性配置（推荐）

在本地运行一次配置脚本：

```bash
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
./setup-vps-git.sh
```

这会在 VPS 上配置 Git，避免以后的冲突。

---

### 📋 最佳实践

**黄金法则：永远不要在 VPS 上直接修改代码！**

```
正确流程：
1. 在 Mac 上编辑代码
2. git commit & git push
3. ./deploy.sh chat-gateway

错误做法：
❌ SSH 到 VPS 直接 vim 修改文件
❌ 在 VPS 上 git commit
```

**详细指南：** 查看 `HCChatBackEnd/DEPLOYMENT_BEST_PRACTICES.md`

---

### 🔄 以后的部署流程

```bash
# 1. 在本地编辑代码
vim HCChatBackEnd/chat-gateway/server.js

# 2. 提交
cd HCChatBackEnd
git add .
git commit -m "修改: xxx"
git push origin main

# 3. 一键部署（自动处理所有问题）
./deploy.sh chat-gateway
```

**就这么简单！** ✨

