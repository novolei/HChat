# 🏗️ 代码组织规范

**核心原则：** 清晰、解耦、单一职责、易维护

---

## 📐 总体原则

### 1. 逻辑清晰，层次分明
- ✅ 每个文件有明确的职责
- ✅ 相关功能分组到对应文件夹
- ✅ 避免循环依赖

### 2. 抽象解耦
- ✅ 使用协议/接口定义契约
- ✅ 依赖注入而非硬编码
- ✅ 模块间通过明确的 API 交互

### 3. 避免层层堆叠
- ❌ 不要把所有代码放在一个文件
- ✅ 功能超过 300 行考虑拆分
- ✅ 单个文件职责单一

### 4. 文件夹结构清晰
- ✅ 按功能/层次组织文件夹
- ✅ 文件名清晰描述内容
- ✅ 相关文件放在同一目录

---

## 📱 iOS 端组织规范

### 推荐的目录结构

```
HChat/
├── App/                          # 应用入口和配置
│   ├── HChatApp.swift           # App 入口
│   ├── AppEnvironment.swift     # 环境配置
│   └── AppDelegate.swift        # (如需要) App 生命周期
│
├── Core/                         # 核心业务逻辑
│   ├── Networking/              # 网络层
│   │   ├── HackChatClient.swift
│   │   ├── MinIOService.swift
│   │   └── WebSocketManager.swift (未来可拆分)
│   │
│   ├── Models/                  # 数据模型
│   │   ├── ChatMessage.swift
│   │   ├── Channel.swift
│   │   ├── User.swift
│   │   └── Attachment.swift
│   │
│   ├── Services/                # 业务服务
│   │   ├── CallManager.swift
│   │   ├── NotificationManager.swift
│   │   ├── UploadManager.swift
│   │   ├── UploadManager+E2EE.swift
│   │   └── AttachmentService.swift
│   │
│   ├── Parsers/                 # 解析器
│   │   ├── CommandParser.swift
│   │   └── MessageRenderer.swift
│   │
│   └── Crypto/                  # 加密相关
│       ├── E2EE.swift
│       └── KeyManager.swift (未来)
│
├── UI/                          # UI 组件（可复用）
│   ├── Components/              # 通用组件
│   │   ├── MessageBubble.swift
│   │   ├── AttachmentView.swift
│   │   ├── RichText.swift
│   │   └── Components.swift
│   │
│   ├── Theme/                   # 主题和样式
│   │   ├── Theme.swift
│   │   ├── Colors.swift
│   │   └── Typography.swift
│   │
│   └── Modifiers/               # 自定义 Modifier
│       └── CustomModifiers.swift
│
├── Views/                       # 页面级视图
│   ├── Chat/                    # 聊天相关
│   │   ├── ChatView.swift
│   │   ├── ChatInputView.swift (可拆分)
│   │   └── ChatMessageListView.swift (可拆分)
│   │
│   ├── Channel/                 # 频道相关
│   │   ├── ChannelListView.swift
│   │   └── CreateChannelView.swift
│   │
│   ├── Call/                    # 通话相关
│   │   └── CallView.swift
│   │
│   └── Debug/                   # 调试相关
│       └── DebugPanelView.swift
│
├── Utils/                       # 工具类
│   ├── Extensions/              # 扩展
│   │   ├── String+Extensions.swift
│   │   ├── View+Extensions.swift
│   │   └── Date+Extensions.swift
│   │
│   ├── Helpers/                 # 辅助工具
│   │   ├── DebugLogger.swift
│   │   └── FileHelper.swift
│   │
│   └── Notifications/           # 通知相关
│       └── Notifications+Haptics.swift
│
├── Resources/                   # 资源文件
│   ├── Assets.xcassets/
│   ├── Localizable.strings (未来)
│   └── Fonts/ (如需要)
│
└── Deprecated/                  # 待删除的旧代码
    ├── CallManager_old.swift
    ├── HackChatClient_od.swift
    └── Components_old.swift
```

---

### 🔍 当前问题和建议改进

#### 问题 1: 根目录文件散乱

**当前状态：**
```
HChat/
├── AppMain.swift            ❌ 应该在 App/
├── AttachmentService.swift  ❌ 应该在 Core/Services/
├── CallManager_old.swift    ❌ 旧文件，应删除或移到 Deprecated/
├── ContentView.swift        ❌ 应该在 Views/
├── E2EE.swift              ❌ 应该在 Core/Crypto/
├── HackChatClient_od.swift ❌ 旧文件，应删除
├── Notifications+Haptics.swift ❌ 应该在 Utils/Notifications/
├── RichText.swift          ❌ 应该在 UI/Components/
└── Theme.swift             ❌ 应该在 UI/Theme/
```

**建议改进：**
```bash
# 1. 创建新的文件夹结构
mkdir -p HChat/Core/{Networking,Models,Services,Parsers,Crypto}
mkdir -p HChat/UI/{Components,Theme,Modifiers}
mkdir -p HChat/Views/{Chat,Channel,Call,Debug}
mkdir -p HChat/Utils/{Extensions,Helpers,Notifications}
mkdir -p HChat/Resources
mkdir -p HChat/Deprecated

# 2. 移动文件到合适位置
mv HChat/AppMain.swift HChat/App/
mv HChat/AttachmentService.swift HChat/Core/Services/
mv HChat/E2EE.swift HChat/Core/Crypto/
mv HChat/RichText.swift HChat/UI/Components/
mv HChat/Theme.swift HChat/UI/Theme/
mv HChat/Notifications+Haptics.swift HChat/Utils/Notifications/

# 3. 移动旧文件到 Deprecated
mv HChat/CallManager_old.swift HChat/Deprecated/
mv HChat/HackChatClient_od.swift HChat/Deprecated/
mv HChat/Views/Components_old.swift HChat/Deprecated/

# 4. 重新组织 Core 文件夹
mv HChat/Core/HackChatClient.swift HChat/Core/Networking/
mv HChat/Core/MinIOService.swift HChat/Core/Networking/
mv HChat/Core/Models.swift HChat/Core/Models/
mv HChat/Core/CallManager.swift HChat/Core/Services/
mv HChat/Core/NotificationManager.swift HChat/Core/Services/
mv HChat/Core/UploadManager.swift HChat/Core/Services/
mv HChat/Core/UploadManager+E2EE.swift HChat/Core/Services/
mv HChat/Core/CommandParser.swift HChat/Core/Parsers/
mv HChat/Core/MessageRenderer.swift HChat/Core/Parsers/

# 5. 移动 Assets
mv HChat/Assets.xcassets HChat/Resources/
```

#### 问题 2: ChatView.swift 过大

**当前状态：**
- `ChatView.swift` 包含：消息列表、输入框、工具栏、搜索、频道切换等
- 超过 150 行，职责不单一

**建议拆分：**

```swift
// Views/Chat/ChatView.swift (主视图，协调器)
struct ChatView: View {
    var client: HackChatClient
    @State var callManager = CallManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChatMessageListView(client: client)
                ChatInputView(client: client)
            }
            .navigationTitle("#\(client.currentChannel)")
            .toolbar { ChatToolbarContent(client: client) }
        }
    }
}

// Views/Chat/ChatMessageListView.swift (消息列表)
struct ChatMessageListView: View {
    var client: HackChatClient
    @State private var searchText = ""
    
    var body: some View {
        // 消息列表实现
    }
}

// Views/Chat/ChatInputView.swift (输入框)
struct ChatInputView: View {
    var client: HackChatClient
    @State private var inputText = ""
    
    var body: some View {
        // 输入框实现
    }
}

// Views/Chat/ChatToolbarContent.swift (工具栏)
struct ChatToolbarContent: ToolbarContent {
    var client: HackChatClient
    
    var body: some ToolbarContent {
        // 工具栏实现
    }
}
```

#### 问题 3: HackChatClient.swift 职责过多

**当前状态：**
- `HackChatClient.swift` 超过 400 行
- 包含：WebSocket 管理、消息处理、加密、命令解析、频道管理等

**建议拆分：**

```swift
// Core/Networking/HackChatClient.swift (WebSocket 连接管理)
@MainActor @Observable
class HackChatClient {
    private var webSocket: URLSessionWebSocketTask?
    private let messageHandler: MessageHandler
    private let commandHandler: CommandHandler
    
    func connect() { }
    func disconnect() { }
    func send(_ message: String) { }
}

// Core/Networking/MessageHandler.swift (消息处理)
@MainActor
class MessageHandler {
    func handle(data: Data, client: HackChatClient) async { }
    private func processMessage(_ msg: ChatMessage) { }
}

// Core/Networking/CommandHandler.swift (命令处理)
@MainActor
class CommandHandler {
    func handle(command: Command, client: HackChatClient) { }
}

// Core/Models/ChatState.swift (聊天状态)
@MainActor @Observable
class ChatState {
    var messages: [String: [ChatMessage]] = [:]
    var channels: [Channel] = []
    var currentChannel = "lobby"
    var onlineUsers: [String: Set<String>] = [:]
}
```

---

## 🖥️ 后端组织规范

### 推荐的目录结构

```
HCChatBackEnd/
├── chat-gateway/                # WebSocket 聊天服务
│   ├── src/                    # 源代码
│   │   ├── handlers/           # 消息处理器
│   │   │   ├── joinHandler.js
│   │   │   ├── nickHandler.js
│   │   │   ├── messageHandler.js
│   │   │   └── index.js
│   │   │
│   │   ├── services/           # 业务逻辑
│   │   │   ├── roomManager.js
│   │   │   ├── userManager.js
│   │   │   └── broadcaster.js
│   │   │
│   │   ├── utils/              # 工具函数
│   │   │   ├── logger.js
│   │   │   └── validation.js
│   │   │
│   │   ├── config/             # 配置
│   │   │   └── index.js
│   │   │
│   │   └── server.js           # 入口文件（简洁）
│   │
│   ├── tests/                  # 测试
│   │   ├── handlers.test.js
│   │   └── services.test.js
│   │
│   ├── Dockerfile
│   ├── package.json
│   └── README.md
│
├── message-service/            # REST API 服务
│   ├── src/
│   │   ├── routes/            # 路由定义
│   │   │   ├── minio.js
│   │   │   ├── livekit.js
│   │   │   └── health.js
│   │   │
│   │   ├── controllers/       # 控制器
│   │   │   ├── minioController.js
│   │   │   └── livekitController.js
│   │   │
│   │   ├── services/          # 业务逻辑
│   │   │   ├── minioService.js
│   │   │   └── livekitService.js
│   │   │
│   │   ├── middleware/        # 中间件
│   │   │   ├── auth.js
│   │   │   └── errorHandler.js
│   │   │
│   │   ├── utils/             # 工具函数
│   │   │   └── logger.js
│   │   │
│   │   ├── config/            # 配置
│   │   │   └── index.js
│   │   │
│   │   └── server.js          # 入口文件
│   │
│   ├── tests/
│   ├── Dockerfile
│   ├── package.json
│   └── README.md
│
├── shared/                     # 共享代码（如需要）
│   ├── types/                 # TypeScript 类型定义
│   ├── constants/             # 常量
│   └── utils/                 # 通用工具
│
├── infra/                      # 基础设施配置
│   ├── docker-compose.yml
│   ├── coturn/
│   ├── fastpanel/
│   └── livekit.yaml
│
├── scripts/                    # 运维脚本
│   ├── deploy.sh
│   ├── ai-deploy.sh
│   └── service-manager.sh
│
└── docs/                       # 文档
    ├── API.md
    ├── ARCHITECTURE.md
    └── DEPLOYMENT.md
```

---

### 🔍 当前问题和建议改进

#### 问题 1: server.js 单文件过大

**当前 chat-gateway/server.js 结构：**
```javascript
// 150 行包含：
- WebSocket 服务器设置
- 连接管理
- 消息路由
- join/nick/who/message 处理
- 房间管理
- 广播逻辑
```

**建议拆分：**

**`chat-gateway/src/server.js` (入口，20 行)**
```javascript
const WebSocket = require('ws');
const config = require('./config');
const { handleMessage } = require('./handlers');
const { handleConnection, handleClose } = require('./handlers/connectionHandler');

const wss = new WebSocket.Server({ port: config.PORT });

wss.on('connection', (ws) => {
    handleConnection(ws);
    
    ws.on('message', (data) => handleMessage(ws, data));
    ws.on('close', () => handleClose(ws));
});

console.log(`chat-gateway listening on :${config.PORT}`);
```

**`chat-gateway/src/handlers/index.js` (消息路由，30 行)**
```javascript
const joinHandler = require('./joinHandler');
const nickHandler = require('./nickHandler');
const whoHandler = require('./whoHandler');
const messageHandler = require('./messageHandler');

function handleMessage(ws, data) {
    let msg = {};
    try { 
        msg = JSON.parse(data.toString()); 
    } catch { 
        return; 
    }

    const msgType = msg.type || msg.cmd;

    switch (msgType) {
        case 'join': return joinHandler(ws, msg);
        case 'nick': return nickHandler(ws, msg);
        case 'who': return whoHandler(ws, msg);
        case 'message':
        case 'chat': return messageHandler(ws, msg);
        default: return;
    }
}

module.exports = { handleMessage };
```

**`chat-gateway/src/handlers/joinHandler.js` (单一职责，25 行)**
```javascript
const { broadcast } = require('../services/broadcaster');
const roomManager = require('../services/roomManager');

function handleJoin(ws, msg) {
    const channel = msg.room || msg.channel;
    if (!channel) return;

    ws.channel = channel;
    ws.nick = ws.nick || msg.nick || 'guest';
    
    roomManager.addUser(ws.channel, ws);
    
    broadcast(ws.channel, {
        type: 'user_joined',
        nick: ws.nick,
        channel: ws.channel
    }, ws);
    
    sendConfirmation(ws, `joined #${ws.channel}`);
}

function sendConfirmation(ws, text) {
    if (ws.readyState === 1) {
        try {
            ws.send(JSON.stringify({ type: 'info', text }));
        } catch (err) {
            console.error('send confirmation error:', err.message);
        }
    }
}

module.exports = handleJoin;
```

**`chat-gateway/src/services/roomManager.js` (房间管理，30 行)**
```javascript
const rooms = new Map();

function addUser(channel, ws) {
    if (!rooms.has(channel)) {
        rooms.set(channel, new Set());
    }
    rooms.get(channel).add(ws);
}

function removeUser(channel, ws) {
    const room = rooms.get(channel);
    if (!room) return;
    
    room.delete(ws);
    if (room.size === 0) {
        rooms.delete(channel);
    }
}

function getUsers(channel) {
    const room = rooms.get(channel);
    if (!room) return [];
    
    return Array.from(room).map(ws => ws.nick || 'guest');
}

function getRoomUsers(channel) {
    return rooms.get(channel) || new Set();
}

module.exports = {
    addUser,
    removeUser,
    getUsers,
    getRoomUsers
};
```

**`chat-gateway/src/services/broadcaster.js` (广播服务，20 行)**
```javascript
const roomManager = require('./roomManager');

function broadcast(channel, packet, excludeWs = null) {
    const users = roomManager.getRoomUsers(channel);
    const text = JSON.stringify(packet);
    
    for (const ws of users) {
        if (ws === excludeWs) continue;
        
        if (ws.readyState === 1) {
            try {
                ws.send(text);
            } catch (err) {
                console.error('broadcast send error:', err.message);
            }
        }
    }
}

module.exports = { broadcast };
```

---

## 📋 文件拆分决策流程图

```
需要添加新功能？
    │
    ├─ 是否是独立的业务逻辑？
    │   ├─ 是 → 创建新的 Service 文件
    │   └─ 否 → 继续
    │
    ├─ 是否是 UI 组件？
    │   ├─ 是 → 创建新的 Component 文件
    │   └─ 否 → 继续
    │
    ├─ 是否是工具函数？
    │   ├─ 是 → 添加到 Utils 或创建新的 Helper
    │   └─ 否 → 继续
    │
    ├─ 是否是数据模型？
    │   ├─ 是 → 创建新的 Model 文件
    │   └─ 否 → 继续
    │
    ├─ 当前文件是否超过 200 行？
    │   ├─ 是 → 拆分为多个文件
    │   └─ 否 → 可以添加到当前文件
    │
    └─ 是否有类似功能的文件夹？
        ├─ 是 → 添加到该文件夹
        └─ 否 → 创建新的文件夹
```

---

## 🎯 最佳实践

### 1. 单一职责原则 (SRP)

```swift
// ❌ 不好：一个类做太多事
class ChatManager {
    func connect() { }
    func sendMessage() { }
    func uploadFile() { }
    func encryptMessage() { }
    func parseCommand() { }
    func renderMarkdown() { }
}

// ✅ 好：每个类单一职责
class WebSocketClient { func connect() { } }
class MessageSender { func send() { } }
class FileUploader { func upload() { } }
class Encryptor { func encrypt() { } }
class CommandParser { func parse() { } }
class MarkdownRenderer { func render() { } }
```

---

### 2. 依赖注入

```swift
// ❌ 不好：硬编码依赖
class ChatView: View {
    let client = HackChatClient() // 直接创建
}

// ✅ 好：依赖注入
class ChatView: View {
    var client: HackChatClient  // 外部传入
}

// 在 App 入口初始化
@main
struct HChatApp: App {
    @State var client = HackChatClient()
    
    var body: some Scene {
        WindowGroup {
            ChatView(client: client)
        }
    }
}
```

---

### 3. 协议抽象

```swift
// ✅ 定义协议
protocol ChatClientProtocol {
    func sendMessage(_ text: String)
    func connect()
    func disconnect()
}

// ✅ 实现协议
class HackChatClient: ChatClientProtocol { }
class MockChatClient: ChatClientProtocol { } // 用于测试

// ✅ 依赖协议而非具体类
struct ChatView: View {
    var client: ChatClientProtocol  // 抽象依赖
}
```

---

### 4. 文件大小控制

| 文件类型 | 建议行数 | 超过时操作 |
|---------|---------|----------|
| Model | < 100 | 拆分为多个模型 |
| Service | < 200 | 拆分职责 |
| View | < 150 | 拆分为子视图 |
| Utility | < 150 | 拆分为多个工具类 |

---

### 5. 命名规范

```
iOS (Swift):
- 文件名：PascalCase (ChatView.swift)
- 类/结构体：PascalCase (HackChatClient)
- 方法/变量：camelCase (sendMessage, currentChannel)
- 协议：PascalCase + Protocol 后缀 (ChatClientProtocol)

后端 (JavaScript/Node.js):
- 文件名：camelCase (messageHandler.js)
- 类：PascalCase (RoomManager)
- 函数/变量：camelCase (handleMessage, userList)
- 常量：UPPER_SNAKE_CASE (MAX_USERS, DEFAULT_PORT)

文件夹：
- iOS: PascalCase (Core, Views, Utils)
- 后端: camelCase (handlers, services, utils)
```

---

## 🚀 重构计划

### Phase 1: iOS 文件夹重组 (当前优先)

```bash
# 1. 创建新文件夹结构
# 2. 移动现有文件到对应位置
# 3. 更新 Xcode 项目引用
# 4. 测试编译
# 5. 提交 Git
```

### Phase 2: iOS 大文件拆分

```bash
# 1. 拆分 HackChatClient.swift
# 2. 拆分 ChatView.swift
# 3. 拆分 Models.swift
# 4. 测试功能
# 5. 提交 Git
```

### Phase 3: 后端服务重构

```bash
# 1. chat-gateway 拆分
# 2. message-service 拆分
# 3. 添加单元测试
# 4. 部署测试
# 5. 提交 Git
```

### Phase 4: 共享代码抽象

```bash
# 1. 提取共享类型定义
# 2. 提取共享常量
# 3. 提取共享工具函数
# 4. 统一日志格式
# 5. 提交 Git
```

---

## 📝 检查清单

在添加新功能前，问自己：

- [ ] 这个功能应该放在哪个文件夹？
- [ ] 需要创建新文件还是添加到现有文件？
- [ ] 现有文件是否已经太大（>200 行）？
- [ ] 是否可以抽象为独立的服务或组件？
- [ ] 文件名是否清晰描述其职责？
- [ ] 是否遵循了单一职责原则？
- [ ] 是否使用了依赖注入而非硬编码？
- [ ] 是否有重复代码可以提取？

**只有全部勾选后才开始编码！**

---

## 🎯 总结

### 核心要点

1. **清晰 > 简洁**：宁可多几个文件，也不要一个文件塞满代码
2. **抽象 > 具体**：优先依赖接口/协议，而非具体实现
3. **解耦 > 便利**：模块间松耦合，即使需要多写几行代码
4. **单一职责**：每个文件、类、函数只做一件事
5. **持续重构**：代码组织不是一次性的，要持续改进

### 长期目标

- ✅ 易于测试（单元测试、集成测试）
- ✅ 易于维护（修改一处不影响其他）
- ✅ 易于扩展（添加新功能不改旧代码）
- ✅ 易于理解（新人能快速上手）
- ✅ 易于重用（组件可复用）

---

**🏗️ 良好的代码组织是项目长期健康的基石！**

