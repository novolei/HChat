# HChat 本地-远程调试指南

> 📱 iOS 客户端（本地 Mac）⇄ 🌐 Backend（远程 VPS: hc.go-lv.com）

---

## 一、调试工具概览

### 1. 内置调试系统

我已经为您创建了完整的调试工具链：

- **DebugLogger.swift** - 统一日志系统
- **AppEnvironment.swift** - 环境管理（开发/生产/本地）
- **DebugPanelView.swift** - 应用内调试面板
- 自动网络请求日志（HTTP + WebSocket）
- 加密消息跟踪

### 2. 使用方法

在您的 App 中添加调试面板入口（仅 DEBUG 模式）：

```swift
// 在某个设置界面或主界面添加
#if DEBUG
NavigationLink("🔧 开发者工具") {
    DebugPanelView()
}
#endif
```

---

## 二、调试最佳实践

### 🔍 1. 日志查看方式

#### 方式一：Xcode 控制台（推荐）
运行 App 时，所有日志实时显示在 Xcode 控制台：

```
[🌐 NETWORK] 📤 HTTP 请求
🎯 POST https://hc.go-lv.com/api/attachments/presign
📋 Headers:
  Content-Type: application/json
📦 Body:
{"objectKey":"rooms/lobby/2025/10/21/test.jpg","contentType":"image/jpeg"}
⏰ 2025-10-21T10:30:45Z

[🌐 NETWORK] 📥 HTTP 响应
✅ Status: 200
🎯 URL: https://hc.go-lv.com/api/attachments/presign
📦 Body:
{"putUrl":"https://s3.hc.go-lv.com/...","getUrl":"..."}
```

#### 方式二：macOS Console.app
1. 打开 Console.app
2. 选择您的 iPhone/Simulator
3. 搜索 `com.hchat.app`
4. 可以导出日志文件

#### 方式三：应用内实时日志
在 `DebugPanelView` 中查看关键指标和连接状态

---

### 🌐 2. 网络请求调试

#### HTTP 请求跟踪
所有 REST API 请求会自动记录：
- 请求 URL、方法、Headers、Body
- 响应状态码、Headers、Body
- 请求耗时和上传/下载速度

```swift
// 自动记录的请求示例
let response = try await Services.minio.presign(
    objectKey: "test.jpg", 
    contentType: "image/jpeg"
)
// 控制台会显示完整的请求/响应详情
```

#### WebSocket 消息跟踪
WebSocket 消息会区分明文和密文：

```
[🔌 WEBSOCKET] 📤 发送
🔐 已加密
💬 内容: [加密消息]
📏 长度: 245 字节

[🔌 WEBSOCKET] 📥 接收
🔐 已加密
💬 内容: [加密消息 from alice]
```

#### 使用 Charles/Proxyman 抓包

1. **配置 iOS 设备代理**
   ```
   设置 → Wi-Fi → 您的网络 → 配置代理
   服务器: 您的 Mac IP
   端口: 8888（Charles 默认）
   ```

2. **安装 Charles 证书**
   ```
   Help → SSL Proxying → Install Charles Root Certificate on Mobile Device
   ```

3. **在 Charles 中添加 SSL 代理**
   ```
   Proxy → SSL Proxying Settings → Add
   Host: hc.go-lv.com, s3.hc.go-lv.com
   Port: 443
   ```

4. **查看流量**
   - HTTP 请求：可以看到完整的请求/响应
   - WebSocket：可以看到握手过程
   - 文件上传：可以看到直传 MinIO 的过程

---

### 🔐 3. 加密消息调试

#### 查看加密前后的内容

在 `E2EE.swift` 中添加临时日志：

```swift
func encrypt(_ plaintext: String, key: Data) -> String? {
    DebugLogger.log("🔐 加密前: \(plaintext)", level: .crypto)
    let ciphertext = // ... 加密逻辑
    DebugLogger.log("🔐 加密后: \(ciphertext?.prefix(50) ?? "")", level: .crypto)
    return ciphertext
}
```

#### 验证端到端加密

1. 打开两个客户端（或两台设备）
2. 使用相同的群口令
3. 在控制台查看：
   - 明文消息 → 密文 → WebSocket 发送
   - WebSocket 接收 → 密文 → 明文消息
4. 确认服务器只看到密文（查看 VPS 日志）

---

### 🖥️ 4. VPS Backend 调试

#### SSH 连接到 VPS

```bash
ssh your-user@hc.go-lv.com
```

#### 查看 Docker 服务状态

```bash
cd /root/hc-stack/infra  # 或您的实际路径
docker compose ps
docker compose logs -f chat-gateway
docker compose logs -f message-service
```

#### 实时查看 chat-gateway 日志

```bash
# 进入容器
docker compose exec chat-gateway sh

# 或直接查看日志
docker compose logs -f chat-gateway | grep "chat"
```

示例输出：
```
chat-gateway  | {"cmd":"join","channel":"lobby","nick":"alice"}
chat-gateway  | {"cmd":"chat","text":"E2EE:eyJpdiI6..."}  // 密文
```

#### 查看 message-service 日志

```bash
docker compose logs -f message-service
```

示例输出：
```
message-service | POST /api/attachments/presign
message-service | { objectKey: 'rooms/lobby/2025/10/21/uuid.bin' }
message-service | presigned PUT URL generated
```

#### 监控 MinIO 上传

```bash
# MinIO 日志
docker compose logs -f minio | grep "PUT"

# 或访问 MinIO 控制台
# https://mc.s3.hc.go-lv.com
# 查看桶内的文件
```

#### 网络流量监控

```bash
# 实时监控端口 10080 (WebSocket)
sudo tcpdump -i any -A 'port 10080'

# 监控 MinIO 上传
sudo tcpdump -i any -A 'port 10090'
```

---

### 🐛 5. 常见问题排查

#### 问题：WebSocket 连接失败

**排查步骤：**

1. **检查网络**
   ```swift
   // 在 Xcode 控制台查看
   [🔌 WEBSOCKET] 🔌 连接 WebSocket: wss://hc.go-lv.com/chat-ws
   [❌ ERROR] WebSocket 连接失败: ...
   ```

2. **检查 VPS 服务**
   ```bash
   # SSH 到 VPS
   docker compose ps
   # 确认 chat-gateway 运行中
   
   curl http://127.0.0.1:10080/chat-ws
   # 应该返回 WebSocket 升级响应
   ```

3. **检查防火墙**
   ```bash
   sudo ufw status
   # 确保 80, 443 开放
   ```

4. **检查 Nginx**
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   tail -f /var/log/nginx/error.log
   ```

#### 问题：文件上传失败

**排查步骤：**

1. **查看预签名 URL 请求**
   ```
   [🌐 NETWORK] POST /api/attachments/presign
   ✅ Status: 200
   ```

2. **查看上传日志**
   ```
   [🌐 NETWORK] 📤 开始上传文件到 MinIO: 1048576 字节
   [🌐 NETWORK] ✅ 文件上传成功 - 耗时: 2.35s, 速度: 0.42 MB/s
   ```

3. **检查 MinIO 服务**
   ```bash
   docker compose logs -f minio
   curl http://127.0.0.1:10090/minio/health/ready
   ```

4. **检查桶配置**
   ```bash
   # 访问 MinIO 控制台
   https://mc.s3.hc.go-lv.com
   # 确认 hc-attachments 桶存在且可访问
   ```

#### 问题：加密消息无法解密

**排查步骤：**

1. **确认群口令一致**
   ```swift
   DebugLogger.log("群口令: \(passphraseForEndToEndEncryption)", level: .crypto)
   ```

2. **查看加密日志**
   ```
   [🔐 CRYPTO] ✅ 加密
   📥 输入: Hello World
   📤 输出: E2EE:eyJpdiI6...
   ```

3. **查看解密日志**
   ```
   [🔐 CRYPTO] ❌ 解密失败
   错误: Invalid authentication tag
   ```

---

### 📊 6. 性能监控

#### 网络延迟测试

在 `DebugPanelView` 中启用 "模拟网络延迟"：

```swift
AppEnvironment.simulateNetworkDelay = true
AppEnvironment.networkDelaySeconds = 2.0
```

#### 上传速度监控

日志会自动显示上传速度：

```
✅ 文件上传成功 - 耗时: 3.25s, 速度: 1.85 MB/s
```

#### WebSocket 消息延迟

添加时间戳对比：

```swift
// 发送消息时记录时间
let sendTime = Date()
send(message)

// 收到回显时计算延迟
let latency = Date().timeIntervalSince(sendTime)
DebugLogger.log("消息往返延迟: \(latency * 1000)ms", level: .info)
```

---

### 🔄 7. 环境切换

#### 在应用内切换环境

1. 打开 `DebugPanelView`
2. 选择环境：
   - 🚀 生产环境（hc.go-lv.com）
   - 🔧 开发环境（hc.go-lv.com，可配置为测试域名）
   - 💻 本地测试（localhost，需本地运行 Docker）

3. 切换后会自动更新所有 URL

#### 本地运行 Backend（可选）

如果您想在本地完全调试：

```bash
# 在本地 Mac 运行 Docker Compose
cd HCChatBackEnd/infra
docker compose up -d

# 在 App 中切换到 "本地测试" 环境
# API: http://localhost:10081
# WebSocket: ws://localhost:10080/chat-ws
# MinIO: http://localhost:10090
```

---

## 三、调试工作流建议

### 开发新功能时

```
1. 在 DebugPanelView 启用 "详细日志"
2. 切换到 "开发环境"
3. 在 Xcode 控制台观察所有网络请求
4. 使用 Charles 抓包验证请求正确性
5. SSH 到 VPS 查看后端日志
6. 对比客户端和服务端日志
```

### 排查 Bug 时

```
1. 复现问题
2. 查看 Xcode 控制台，定位错误日志
3. 检查网络请求是否成功
4. SSH 到 VPS 查看后端错误
5. 使用 tcpdump 抓包（如果是协议问题）
6. 导出 Console.app 日志分析
```

### 测试端到端加密

```
1. 两台设备，使用相同群口令
2. 启用 "详细日志" + 加密日志
3. 发送消息，对比两端的加密/解密日志
4. 在 VPS 上确认服务器只看到密文
5. 使用 Charles 确认网络传输的是密文
```

---

## 四、推荐工具

### 必备工具

- **Xcode Console** - 实时日志查看
- **macOS Console.app** - 系统日志导出
- **Charles/Proxyman** - HTTP/HTTPS 抓包
- **SSH Client** - 远程 VPS 调试
- **Docker Desktop** - 本地运行 Backend（可选）

### Chrome 扩展（VPS 管理）

- **JSON Formatter** - 格式化 API 响应
- **WebSocket King** - 测试 WebSocket 连接

### 命令行工具

```bash
# HTTP 测试
curl -X POST https://hc.go-lv.com/api/attachments/presign \
  -H "Content-Type: application/json" \
  -d '{"objectKey":"test.jpg","contentType":"image/jpeg"}'

# WebSocket 测试
websocat wss://hc.go-lv.com/chat-ws

# MinIO 测试
mc alias set hc https://s3.hc.go-lv.com ACCESS_KEY SECRET_KEY
mc ls hc/hc-attachments
```

---

## 五、性能优化建议

### 1. 减少日志开销

```swift
// 生产环境自动禁用日志
#if DEBUG
DebugLogger.log("...")
#endif
```

### 2. 批量请求

```swift
// 避免频繁请求预签名 URL
// 改为批量请求多个文件的预签名 URL
```

### 3. 连接池

```swift
// 复用 URLSession
static let shared = URLSession.shared
```

---

## 六、安全注意事项

⚠️ **重要提醒**

1. **不要提交敏感信息**
   - 日志中可能包含 API 密钥、token
   - 提交前检查 `.gitignore`

2. **生产环境禁用调试**
   - Release 版本自动禁用 `DebugLogger`
   - 禁用 `DebugPanelView`

3. **VPS 安全**
   - 定期更新 Docker 镜像
   - 限制 SSH 访问
   - 使用防火墙规则

---

## 七、联系与支持

如遇问题：

1. 查看本文档的常见问题章节
2. 检查 Xcode 控制台和 VPS 日志
3. 使用 Charles 抓包分析
4. 查看 `Product.md` 了解架构细节

---

**祝调试顺利！🎉**

