# 🛡️ 如何避免 VPS Git 冲突

## 📋 问题回顾

之前遇到的问题：
```
error: Your local changes to the following files would be overwritten by merge:
    chat-gateway/server.js
Please commit your changes or stash them before you merge.
```

**原因：** VPS 上有本地修改或提交，与远程代码冲突。

---

## ✅ 解决方案（已实施）

### 1️⃣ 改进的部署脚本

`deploy.sh` 现在会**自动处理**这些问题：

```bash
# 使用部署脚本（推荐）
cd HCChatBackEnd
./deploy.sh chat-gateway
```

**自动处理：**
- ✅ 检测 VPS 本地修改
- ✅ 自动 stash 保存
- ✅ 强制同步到远程最新代码
- ✅ 重启服务

---

### 2️⃣ 一次性配置（可选）

配置 VPS Git 环境，避免将来的问题：

```bash
cd HCChatBackEnd
./setup-vps-git.sh
```

这会在 VPS 上：
- 配置 Git pull 策略为 fast-forward only
- 保存现有本地修改到 stash
- 同步到远程最新版本

---

## 🎯 最佳实践（必读）

### 黄金法则

```
┌─────────────────────────────────────────┐
│  永远不要在 VPS 上直接修改代码！       │
│                                         │
│  开发 → 提交 → 推送 → 部署             │
│  (Mac)  (Git) (GitHub) (VPS)           │
└─────────────────────────────────────────┘
```

### 正确的开发流程

```bash
# 1. 在 Mac 上编辑代码
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
vim chat-gateway/server.js

# 2. 本地提交
git add .
git commit -m "修改: xxx"
git push origin main

# 3. 一键部署到 VPS
./deploy.sh chat-gateway
```

---

## ❌ 错误做法（避免）

**不要这样做：**

```bash
# ❌ SSH 到 VPS
ssh root@mx.go-lv.com

# ❌ 直接修改文件
vim /root/hc-stack/chat-gateway/server.js

# ❌ 在 VPS 上提交
git add .
git commit -m "xxx"
```

**为什么不行：**
- 会导致 VPS 和远程代码分歧
- 下次部署时会冲突
- 无法版本控制和团队协作

---

## 🚨 紧急情况处理

### 如果不小心在 VPS 上改了代码

**方法 1: 使用部署脚本（推荐）**
```bash
# 在本地 Mac 上
./deploy.sh chat-gateway
# 脚本会自动处理
```

**方法 2: 手动处理**
```bash
# 在 VPS 上
cd /root/hc-stack
git stash save "临时备份"
git fetch origin
git reset --hard origin/main
cd infra
docker compose restart chat-gateway
```

---

## 📚 相关文档

- **详细最佳实践：** `HCChatBackEnd/DEPLOYMENT_BEST_PRACTICES.md`
- **部署脚本使用：** `HCChatBackEnd/README.md`
- **故障排除：** `HCChatBackEnd/TROUBLESHOOTING.md`

---

## ✨ 总结

### 记住三点

1. **开发在本地** - Mac 上编辑、测试、提交
2. **使用脚本部署** - `./deploy.sh service-name`
3. **VPS 只运行** - 不修改、不提交

### 一句话

**"VPS 是运行环境，不是开发环境"** 🎯

---

**遵循这些实践，就不会再遇到 Git 冲突问题了！** ✨

