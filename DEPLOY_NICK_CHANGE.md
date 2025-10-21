# 🚀 部署昵称变更功能

## ✅ 代码已提交

### iOS 客户端
```
commit d9e3282
✨ feat: 实现昵称变更实时同步功能
```

### 后端服务
```
commit ddbf312
✨ feat: 添加昵称变更广播功能
```

---

## 📋 部署步骤

### 1️⃣ 后端已推送到 GitHub ✅

```bash
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
git push origin main  # ✅ 已完成
```

---

### 2️⃣ 手动部署到 VPS

如果自动部署脚本卡住，手动执行：

```bash
# SSH 登录
ssh root@mx.go-lv.com

# 更新代码
cd /root/hc-stack
git fetch origin
git reset --hard origin/main

# 重启服务
cd infra
docker compose restart chat-gateway

# 查看日志确认启动成功
docker compose logs -f chat-gateway
```

**或使用一键命令：**
```bash
ssh root@mx.go-lv.com 'cd /root/hc-stack && git fetch origin && git reset --hard origin/main && cd infra && docker compose restart chat-gateway && docker compose logs --tail=20 chat-gateway'
```

---

### 3️⃣ iOS 客户端测试

```bash
# 在 Xcode 中
1. 打开项目: open HChat.xcodeproj
2. 清理构建: Cmd + Shift + K
3. 重新编译: Cmd + B
4. 运行: Cmd + R
```

---

## 🧪 测试步骤

### 快速测试

1. **启动 App 并发送消息**
   ```
   输入: "测试消息1"
   输入: "测试消息2"
   ```

2. **修改昵称**
   ```
   输入: /nick 新名字
   ```

3. **验证结果**
   - ✅ 之前的消息发送者显示为 "新名字"
   - ✅ 看到系统提示 "iOSUser 更名为 新名字"
   - ✅ 后续消息使用新昵称

---

### 多设备测试

**设备 1:**
```
连接 → 发送 "我是设备1" → 输入 /nick Alice
```

**设备 2:**
```
连接 → 观察设备1的消息
```

**预期结果（设备2看到）:**
```
[iOSUser] 我是设备1
[system] iOSUser 更名为 Alice
[Alice] 我是设备1        ← 自动更新
```

---

## 🔍 调试

### 查看后端日志

```bash
ssh root@mx.go-lv.com
cd /root/hc-stack/infra
docker compose logs -f chat-gateway | grep "nick"
```

**预期输出：**
```
收到消息: {type: 'nick', nick: 'Alice'}
广播 nick_change: oldNick='iOSUser', newNick='Alice'
```

### 查看 iOS 日志

在 Xcode 控制台应该看到：
```
📥 收到消息 - type: nick_change
👤 昵称变更: iOSUser → Alice (频道: lobby)
➕ appendMessage - sender: system
```

---

## ✅ 验证清单

- [ ] 后端代码已推送到 GitHub
- [ ] chat-gateway 服务已重启
- [ ] 服务日志显示正常启动
- [ ] iOS App 已重新编译
- [ ] 单设备测试通过
- [ ] 多设备测试通过（可选）
- [ ] 昵称变更提示显示正确
- [ ] 历史消息昵称更新正确

---

## 📚 功能文档

详细说明请查看: `NICK_CHANGE_FEATURE.md`

---

**部署后即可体验昵称实时同步功能！** 🎉

