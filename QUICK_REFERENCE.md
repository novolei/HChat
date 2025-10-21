# 🚀 HChat 快速参考

## 📦 常用命令

### iOS 开发

```bash
# 打开项目
cd /Users/ryanliu/DDCS/HChat
open HChat.xcodeproj

# 提交代码
./git-backup.sh "修改说明"

# 快速保存（临时）
./quick-save.sh "测试中"
```

---

### 后端部署

```bash
# 一键部署（推荐）✅
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
./deploy.sh chat-gateway
./deploy.sh message-service

# 部署所有服务
./deploy.sh all
```

---

### VPS 管理

**重要：所有 docker compose 命令都需要在 infra 目录下执行！**

```bash
# SSH 登录
ssh root@mx.go-lv.com

# 查看服务状态
cd /root/hc-stack/infra
docker compose ps

# 查看日志
docker compose logs -f chat-gateway
docker compose logs -f message-service
docker compose logs -f minio

# 重启服务
docker compose restart chat-gateway
docker compose restart message-service

# 重启所有服务
docker compose restart

# 查看所有服务日志
docker compose logs --tail=100
```

---

### Git 工作流

```bash
# 本地开发
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
vim chat-gateway/server.js

# 提交
git add .
git commit -m "修改: xxx"
git push origin main

# 部署
./deploy.sh chat-gateway
```

---

## 🔧 故障排查

### iOS App 问题

```bash
# 1. 查看 Xcode 控制台日志
# 2. 检查 DebugLogger 输出
# 3. 检查 WebSocket 连接状态
```

### 后端问题

```bash
# 查看 chat-gateway 日志
ssh root@mx.go-lv.com
cd /root/hc-stack/infra
docker compose logs --tail=50 chat-gateway

# 检查服务健康
docker compose ps
curl http://127.0.0.1:10080/health  # chat-gateway
curl http://127.0.0.1:10081/health  # message-service
```

### Git 冲突

```bash
# 方法 1: 使用部署脚本（自动处理）
./deploy.sh chat-gateway

# 方法 2: 手动修复
ssh root@mx.go-lv.com
cd /root/hc-stack
git fetch origin
git reset --hard origin/main
cd infra
docker compose restart chat-gateway
```

---

## 📂 目录结构

```
/Users/ryanliu/DDCS/HChat/
├── HChat/                    # iOS 源代码
│   ├── App/                 # App 入口和配置
│   ├── Core/                # 核心逻辑
│   ├── UI/                  # 界面组件
│   ├── Utils/               # 工具类
│   └── Views/               # 视图
├── HCChatBackEnd/           # 后端代码（独立仓库）
│   ├── chat-gateway/        # WebSocket 服务
│   ├── message-service/     # REST API 服务
│   ├── infra/               # Docker Compose 配置 ⭐
│   │   └── docker-compose.yml
│   └── deploy.sh            # 部署脚本
├── git-backup.sh            # iOS 备份工具
├── quick-save.sh            # 快速保存工具
└── *.md                     # 文档
```

**VPS 目录结构：**
```
/root/hc-stack/
├── chat-gateway/
├── message-service/
├── infra/                   # ⭐ Docker Compose 工作目录
│   └── docker-compose.yml
└── ...
```

---

## 🌐 服务地址

### 生产环境

- **WebSocket**: wss://hc.go-lv.com/chat-ws
- **API**: https://hc.go-lv.com/api
- **MinIO S3**: https://s3.hc.go-lv.com
- **MinIO Console**: https://mc.s3.hc.go-lv.com
- **LiveKit**: wss://livekit.hc.go-lv.com

### VPS 内部端口

- chat-gateway: 10080
- message-service: 10081
- MinIO API: 10090
- MinIO Console: 10091
- LiveKit: 17880

---

## ⚡️ 快捷操作

### 重启所有服务

```bash
ssh root@mx.go-lv.com 'cd /root/hc-stack/infra && docker compose restart'
```

### 查看所有日志

```bash
ssh root@mx.go-lv.com 'cd /root/hc-stack/infra && docker compose logs --tail=20'
```

### 更新并重启特定服务

```bash
cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
./deploy.sh chat-gateway
```

---

## 📝 注意事项

1. **Docker Compose 路径**
   - ⚠️ 所有 `docker compose` 命令都要在 `/root/hc-stack/infra` 目录下执行
   - ⚠️ 不要在 `/root/hc-stack` 根目录执行

2. **代码修改**
   - ✅ 在 Mac 上编辑
   - ❌ 不要在 VPS 上直接修改

3. **部署流程**
   - ✅ 使用 `./deploy.sh`
   - ❌ 不要手动 `git pull`

---

## 📚 完整文档

- **iOS 调试**: `DEBUGGING.md`
- **部署最佳实践**: `HCChatBackEnd/DEPLOYMENT_BEST_PRACTICES.md`
- **Git 保护**: `GIT_PROTECTION.md`
- **Swift Observation**: `SWIFT_OBSERVATION_RULES.md`
- **故障排查**: `HCChatBackEnd/TROUBLESHOOTING.md`

---

**快速访问此文档：** `cat QUICK_REFERENCE.md`

