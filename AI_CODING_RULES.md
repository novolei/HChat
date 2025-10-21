# 🤖 AI 编码规则速查表

**用途：** AI 助手在开发时的快速决策指南

---

## ⚠️ 提交前必须检查

### 1️⃣ 编译检查（必须）

```python
# iOS 代码
read_lints(paths=[
    "HChat/Core/HackChatClient.swift",
    "HChat/UI/ChatView.swift",
    # ... 所有修改的文件
])

# 必须看到：✅ No linter errors found
# 才能执行 git commit
```

```bash
# 后端代码
cd HCChatBackEnd/chat-gateway
node -c server.js  # 检查语法

cd HCChatBackEnd/message-service
node -c server.js  # 检查语法

# 必须无错误输出
# 才能执行 git commit
```

---

## 📁 文件放置决策树

### 问题：在哪里创建新文件？

#### iOS (Swift)

```
新功能是什么类型？

├─ 网络请求/WebSocket？
│   → Core/Networking/[功能名].swift
│
├─ 数据模型？
│   → Core/Models/[模型名].swift
│
├─ 业务服务（上传、通知、通话等）？
│   → Core/Services/[服务名].swift
│
├─ 加密/安全？
│   → Core/Crypto/[功能名].swift
│
├─ 解析器（命令、消息等）？
│   → Core/Parsers/[解析器名].swift
│
├─ 可复用 UI 组件？
│   → UI/Components/[组件名].swift
│
├─ 主题/样式？
│   → UI/Theme/[主题名].swift
│
├─ 页面级视图？
│   ├─ 聊天相关 → Views/Chat/[视图名].swift
│   ├─ 频道相关 → Views/Channel/[视图名].swift
│   ├─ 通话相关 → Views/Call/[视图名].swift
│   └─ 调试相关 → Views/Debug/[视图名].swift
│
├─ 扩展（String、View、Date 等）？
│   → Utils/Extensions/[类型名]+Extensions.swift
│
├─ 工具函数/辅助类？
│   → Utils/Helpers/[工具名].swift
│
└─ 通知/Haptics？
    → Utils/Notifications/[功能名].swift
```

#### 后端 (Node.js)

```
新功能是什么类型？

├─ WebSocket 消息处理？
│   → chat-gateway/src/handlers/[命令名]Handler.js
│
├─ REST API 路由？
│   → message-service/src/routes/[资源名].js
│
├─ 控制器逻辑？
│   → message-service/src/controllers/[资源名]Controller.js
│
├─ 业务逻辑（房间管理、用户管理等）？
│   ├─ chat-gateway → src/services/[服务名].js
│   └─ message-service → src/services/[服务名].js
│
├─ 工具函数？
│   → src/utils/[工具名].js
│
├─ 配置？
│   → src/config/index.js
│
└─ 中间件（message-service）？
    → src/middleware/[中间件名].js
```

---

## 🚫 禁止的操作

### ❌ 永远不要做的事

1. **提交未检查编译的代码**
   ```bash
   # ❌ 错误
   git add -A && git commit -m "..." && git push
   
   # ✅ 正确
   read_lints([修改的文件])  # iOS
   node -c server.js          # 后端
   # 确认无误后再 commit
   ```

2. **把新功能堆叠在大文件中**
   ```bash
   # ❌ 错误：在 HackChatClient.swift (400 行) 中添加 100 行新功能
   
   # ✅ 正确：创建新文件
   # Core/Services/NewFeatureService.swift
   ```

3. **在根目录创建文件**
   ```bash
   # ❌ 错误
   HChat/MyNewFeature.swift
   
   # ✅ 正确
   HChat/Core/Services/MyNewFeature.swift
   ```

4. **使用旧的 Swift API**
   ```swift
   // ❌ 错误
   @ObservedObject, @StateObject, @Published, ObservableObject
   
   // ✅ 正确
   @Observable, @State, @Bindable
   ```

5. **硬编码依赖**
   ```swift
   // ❌ 错误
   class ChatView: View {
       let client = HackChatClient()  // 直接创建
   }
   
   // ✅ 正确
   class ChatView: View {
       var client: HackChatClient  // 依赖注入
   }
   ```

---

## ✅ 强制的操作

### ✅ 必须要做的事

1. **新功能前检查文件大小**
   ```bash
   # 如果文件超过 200 行，先拆分再添加
   wc -l HChat/Core/HackChatClient.swift
   # 401 行 → 拆分！
   ```

2. **创建新文件时创建对应文件夹**
   ```bash
   # ✅ 如果不存在，先创建文件夹
   mkdir -p HChat/Core/Networking
   # 再创建文件
   touch HChat/Core/Networking/WebSocketManager.swift
   ```

3. **重复代码立即提取**
   ```swift
   // 如果看到重复代码 > 2 次
   // 立即提取为函数或组件
   ```

4. **使用最新 Swift Observation API**
   ```swift
   // ✅ 模型
   @MainActor @Observable
   class MyModel { }
   
   // ✅ App 入口
   @State var model = MyModel()
   
   // ✅ 视图接收
   var model: MyModel
   
   // ✅ 绑定
   @Bindable var model: MyModel
   ```

5. **后端部署使用 AI 智能部署**
   ```bash
   # ✅ 正确
   cd /Users/ryanliu/DDCS/HChat/HCChatBackEnd
   ./ai-deploy.sh chat-gateway
   
   # ❌ 错误
   ./deploy.sh chat-gateway  # 不使用普通部署
   ```

---

## 📐 文件大小警戒线

| 文件类型 | 当前行数 → 操作 |
|---------|----------------|
| **Swift Model** | > 100 行 → 拆分为多个模型 |
| **Swift Service** | > 200 行 → 拆分职责 |
| **Swift View** | > 150 行 → 拆分为子视图 |
| **JavaScript Handler** | > 100 行 → 拆分为多个 handler |
| **JavaScript Service** | > 150 行 → 拆分功能 |

### 当前需要拆分的文件

```bash
# iOS
HackChatClient.swift (401 行) ⚠️ 需要拆分
ChatView.swift (171 行) ⚠️ 接近警戒线

# 后端
chat-gateway/server.js (150 行) ⚠️ 需要拆分
message-service/server.js (估计 ~100 行) ⚠️ 接近警戒线
```

---

## 🔄 开发工作流

### iOS 功能开发流程

```
1. 确定功能位置
   └─ 查看 "文件放置决策树"
   
2. 检查是否需要新文件夹
   └─ mkdir -p HChat/[路径]
   
3. 创建/修改文件
   └─ 使用 write 或 search_replace
   
4. 立即检查编译
   └─ read_lints([修改的文件])
   
5. 发现错误？
   ├─ 是 → 立即修复，回到步骤 4
   └─ 否 → 继续
   
6. 提交代码
   └─ git add && git commit
   
7. 更新 Xcode 项目（如需要）
   └─ 提醒用户在 Xcode 中添加新文件
```

---

### 后端功能开发流程

```
1. 确定功能位置
   └─ 查看 "文件放置决策树"
   
2. 修改代码
   └─ 使用 search_replace
   
3. 检查语法
   └─ node -c server.js
   
4. 提交到 Git
   └─ git add && git commit && git push
   
5. 部署到 VPS
   └─ cd HCChatBackEnd && ./ai-deploy.sh [服务名]
   
6. 检查部署结果
   └─ ai-deploy.sh 会自动分析并报告
   
7. 部署失败？
   └─ 提取错误信息，询问用户
```

---

## 🎯 命名规范速查

### iOS (Swift)

```swift
// 文件名
ChatView.swift              ✅ PascalCase
MessageBubble.swift         ✅ PascalCase
String+Extensions.swift     ✅ PascalCase + 描述

// 类/结构体/枚举
class HackChatClient        ✅ PascalCase
struct ChatMessage          ✅ PascalCase
enum MessageType            ✅ PascalCase

// 协议
protocol ChatClientProtocol ✅ PascalCase + Protocol

// 方法/变量
func sendMessage()          ✅ camelCase
var currentChannel          ✅ camelCase
let messageCount            ✅ camelCase

// 常量
static let maxRetries = 3   ✅ camelCase
```

---

### 后端 (JavaScript)

```javascript
// 文件名
messageHandler.js           ✅ camelCase
roomManager.js              ✅ camelCase

// 类
class RoomManager           ✅ PascalCase

// 函数/变量
function handleMessage()    ✅ camelCase
const userList = []         ✅ camelCase

// 常量
const MAX_USERS = 100       ✅ UPPER_SNAKE_CASE
const DEFAULT_PORT = 3000   ✅ UPPER_SNAKE_CASE
```

---

### 文件夹

```
# iOS
Core/                       ✅ PascalCase
Views/                      ✅ PascalCase
Utils/                      ✅ PascalCase

# 后端
handlers/                   ✅ camelCase
services/                   ✅ camelCase
utils/                      ✅ camelCase
```

---

## 🔍 快速检查清单

### 在创建新文件前

- [ ] 是否查看了文件放置决策树？
- [ ] 是否检查了现有文件大小？
- [ ] 是否需要创建新文件夹？
- [ ] 文件名是否符合命名规范？
- [ ] 是否遵循单一职责原则？

### 在修改文件后

- [ ] 是否检查了编译？(iOS: read_lints, 后端: node -c)
- [ ] 是否发现了重复代码？
- [ ] 文件是否超过大小警戒线？
- [ ] 是否需要拆分文件？

### 在提交代码前

- [ ] ✅ 编译检查通过？
- [ ] 代码是否符合组织规范？
- [ ] 提交信息是否清晰？
- [ ] 是否更新了相关文档？

### 在部署后端前

- [ ] 是否已 push 到 GitHub？
- [ ] 是否使用 ai-deploy.sh？
- [ ] 是否检查了部署结果？

---

## 💡 实战示例

### 示例 1: 添加新的加密功能

```
❓ 需求：添加新的消息签名验证功能

1️⃣ 决策：这是加密相关功能
   → 应该在 Core/Crypto/ 下创建新文件

2️⃣ 检查：是否可以添加到 E2EE.swift？
   → 查看 E2EE.swift 行数：~150 行
   → 添加新功能会超过 200 行 → 不应该添加

3️⃣ 创建新文件
   mkdir -p HChat/Core/Crypto
   touch HChat/Core/Crypto/MessageSigner.swift

4️⃣ 实现功能
   @MainActor @Observable
   class MessageSigner {
       func sign(_ message: String) -> String { }
       func verify(_ signature: String) -> Bool { }
   }

5️⃣ 检查编译
   read_lints(["HChat/Core/Crypto/MessageSigner.swift"])

6️⃣ 提交
   git add HChat/Core/Crypto/MessageSigner.swift
   git commit -m "feat: 添加消息签名验证"
```

---

### 示例 2: 后端添加新的 WebSocket 命令

```
❓ 需求：添加 /mute 命令

1️⃣ 决策：这是消息处理
   → 应该在 chat-gateway/src/handlers/ 创建新 handler

2️⃣ 当前状态：chat-gateway/server.js 是单文件
   → 需要先重构为分层结构（未来任务）
   → 当前临时添加到 server.js

3️⃣ 修改代码
   search_replace(
       file_path="HCChatBackEnd/chat-gateway/server.js",
       old_string="// 处理 who 命令...",
       new_string="// 处理 mute 命令\nif (msgType === 'mute') { ... }\n\n// 处理 who 命令..."
   )

4️⃣ 检查语法
   run_terminal_cmd("cd HCChatBackEnd/chat-gateway && node -c server.js")

5️⃣ 提交
   run_terminal_cmd("cd HCChatBackEnd && git add chat-gateway/server.js && git commit -m 'feat: 添加 mute 命令'")

6️⃣ 推送
   run_terminal_cmd("cd HCChatBackEnd && git push origin main")

7️⃣ 部署
   run_terminal_cmd("cd HCChatBackEnd && ./ai-deploy.sh chat-gateway")
```

---

### 示例 3: 拆分大文件 HackChatClient.swift

```
❓ 当前状态：HackChatClient.swift 401 行，职责过多

1️⃣ 分析职责
   - WebSocket 连接管理
   - 消息处理
   - 命令处理
   - 加密/解密
   - 状态管理

2️⃣ 拆分计划
   ├─ Core/Networking/HackChatClient.swift (WebSocket 连接)
   ├─ Core/Networking/MessageHandler.swift (消息处理)
   ├─ Core/Networking/CommandHandler.swift (命令处理)
   ├─ Core/Models/ChatState.swift (状态管理)
   └─ Core/Crypto/MessageEncryptor.swift (加密，可选)

3️⃣ 创建文件夹
   mkdir -p HChat/Core/Networking
   mkdir -p HChat/Core/Models

4️⃣ 移动现有文件
   mv HChat/Core/HackChatClient.swift HChat/Core/Networking/

5️⃣ 创建新文件并拆分代码
   (逐个创建并提取相应代码)

6️⃣ 更新引用
   (更新 import 和依赖注入)

7️⃣ 检查编译
   read_lints([
       "HChat/Core/Networking/HackChatClient.swift",
       "HChat/Core/Networking/MessageHandler.swift",
       ...
   ])

8️⃣ 测试功能
   (在 Xcode 中运行测试)

9️⃣ 提交
   git add -A
   git commit -m "refactor: 拆分 HackChatClient 为多个专职类"
```

---

## 📚 相关文档

- **[代码组织规范](CODE_ORGANIZATION.md)** - 完整的组织规范
- **[Git 提交检查清单](GIT_COMMIT_CHECKLIST.md)** - 提交前检查
- **[Swift Observation 规则](SWIFT_OBSERVATION_RULES.md)** - Swift API 规范
- **[AI 智能部署指南](HCChatBackEnd/AI_DEPLOY_GUIDE.md)** - 后端部署

---

## 🎉 核心原则（记住这些！）

1. **提交前必须检查编译** ✅
2. **大文件立即拆分** (> 200 行)
3. **新功能创建新文件**，不堆叠
4. **使用文件夹组织**，保持清晰
5. **单一职责**，每个文件只做一件事
6. **依赖注入**，不硬编码
7. **后端部署用 ai-deploy.sh**
8. **使用 @Observable**，不用 ObservableObject

---

**🤖 这是我的编码圣经，每次开发前必看！**

