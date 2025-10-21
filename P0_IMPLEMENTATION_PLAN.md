# 🎯 P0 功能实施计划

**开始日期：** 2025-10-21  
**预计完成：** 1-2 周  
**状态：** 🚀 进行中

---

## 📋 功能概览

| 功能 | 优先级 | 预计时间 | 状态 |
|------|--------|---------|------|
| 消息可靠性 | P0 | 3-4 天 | 🚀 进行中 |
| 搜索增强 | P0 | 2-3 天 | ⏳ 待开始 |
| 通知优化 | P0 | 2-3 天 | ⏳ 待开始 |

---

## 🔥 功能 1: 消息可靠性

### 目标
确保消息 100% 送达，即使在网络不稳定的情况下。

### 技术方案

#### 1.1 本地消息持久化

**文件：** `HChat/Core/Storage/MessagePersistence.swift`

```swift
import CoreData

@MainActor
class MessagePersistence {
    // Core Data Stack
    private let container: NSPersistentContainer
    
    // 保存消息
    func save(message: ChatMessage) async throws
    
    // 获取未发送的消息
    func getPendingMessages() async -> [ChatMessage]
    
    // 更新消息状态
    func updateStatus(messageId: String, status: MessageStatus) async throws
    
    // 删除消息
    func delete(messageId: String) async throws
    
    // 获取频道消息（分页）
    func getMessages(
        channel: String, 
        limit: Int, 
        offset: Int
    ) async -> [ChatMessage]
}
```

**Core Data 模型：**
```swift
// PersistedMessage Entity
class PersistedMessage: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var channel: String
    @NSManaged var sender: String
    @NSManaged var text: String
    @NSManaged var timestamp: Date
    @NSManaged var status: String  // sending, sent, delivered, read
    @NSManaged var retryCount: Int16
    @NSManaged var attachmentsData: Data?  // JSON
}
```

---

#### 1.2 消息状态追踪

**文件：** `HChat/Core/Models/MessageStatus.swift`

```swift
enum MessageStatus: String, Codable {
    case sending    // 📤 发送中（灰色单勾）
    case sent       // ✓ 已送达服务器（灰色双勾）
    case delivered  // ✓✓ 已送达对方（蓝色双勾）
    case read       // ✓✓ 已读（蓝色双勾 + 时间）
    case failed     // ❌ 发送失败
}

extension ChatMessage {
    var statusIcon: String {
        switch status {
        case .sending: return "checkmark"
        case .sent: return "checkmark.2"
        case .delivered: return "checkmark.2"
        case .read: return "checkmark.2"
        case .failed: return "exclamationmark.triangle"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .sending, .sent: return .gray
        case .delivered, .read: return .blue
        case .failed: return .red
        }
    }
}
```

---

#### 1.3 离线消息队列

**文件：** `HChat/Core/Services/MessageQueue.swift`

```swift
@MainActor
@Observable
class MessageQueue {
    private let persistence: MessagePersistence
    private let client: HackChatClient
    
    // 待发送队列
    private var pendingQueue: [ChatMessage] = []
    
    // 发送消息（自动持久化）
    func send(_ message: ChatMessage) async {
        // 1. 保存到本地
        try? await persistence.save(message: message)
        
        // 2. 添加到队列
        pendingQueue.append(message)
        
        // 3. 尝试发送
        await trySend(message)
    }
    
    // 尝试发送
    private func trySend(_ message: ChatMessage) async {
        guard client.isConnected else {
            // 离线，等待重连
            return
        }
        
        do {
            // 发送到服务器
            try await client.sendWithAck(message)
            
            // 更新状态为已发送
            await updateStatus(message.id, to: .sent)
            
            // 从队列移除
            pendingQueue.removeAll { $0.id == message.id }
            
        } catch {
            // 发送失败，增加重试计数
            await incrementRetry(message.id)
            
            // 延迟重试
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            await trySend(message)
        }
    }
    
    // 重连后重发所有待发送消息
    func retryAll() async {
        let pending = await persistence.getPendingMessages()
        for message in pending {
            await trySend(message)
        }
    }
    
    // 更新消息状态
    private func updateStatus(_ messageId: String, to status: MessageStatus) async {
        try? await persistence.updateStatus(messageId: messageId, status: status)
    }
    
    // 增加重试次数
    private func incrementRetry(_ messageId: String) async {
        // 实现重试计数逻辑
    }
}
```

---

#### 1.4 后端 ACK 机制

**文件：** `HCChatBackEnd/chat-gateway/src/handlers/messageHandler.js`

```javascript
// 增强版消息处理（支持 ACK）
function handleMessage(ws, msg) {
  if (!ws.channel || typeof msg.text !== 'string') return;
  
  const messageId = msg.id || generateId();
  
  // 1. 发送 ACK 给发送者
  sendToUser(ws, {
    type: 'message_ack',
    messageId: messageId,
    status: 'received',  // 服务器已收到
    timestamp: Date.now()
  });
  
  // 2. 广播消息到频道
  broadcast(ws.channel, {
    type: 'message',
    channel: ws.channel,
    nick: ws.nick || 'guest',
    text: msg.text,
    id: messageId
  });
  
  // 3. 记录已送达用户（可选）
  const deliveredTo = [];
  const channelUsers = roomManager.getRoomUsers(ws.channel);
  
  for (const user of channelUsers) {
    if (user !== ws && user.readyState === 1) {
      deliveredTo.push(user.nick);
    }
  }
  
  // 4. 发送送达确认
  if (deliveredTo.length > 0) {
    sendToUser(ws, {
      type: 'message_delivered',
      messageId: messageId,
      deliveredTo: deliveredTo,
      timestamp: Date.now()
    });
  }
}
```

---

#### 1.5 UI 显示消息状态

**文件：** `HChat/UI/Components/MessageStatusView.swift`

```swift
struct MessageStatusView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(spacing: 2) {
            // 状态图标
            Image(systemName: message.statusIcon)
                .font(.caption2)
                .foregroundColor(message.statusColor)
            
            // 时间戳
            Text(message.timestamp.formatted(.relative(presentation: .numeric)))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // 已读时间（如果已读）
            if message.status == .read, let readTime = message.readAt {
                Text("· \(readTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
}
```

---

### 实施步骤

#### Day 1: 核心架构
- [x] 创建 MessagePersistence 服务
- [x] 设计 Core Data 模型
- [ ] 实现基本的 CRUD 操作
- [ ] 单元测试

#### Day 2: 消息队列
- [ ] 实现 MessageQueue 服务
- [ ] 添加自动重试机制
- [ ] 集成到 HackChatClient

#### Day 3: 后端 ACK
- [ ] 修改 chat-gateway 支持 ACK
- [ ] 实现消息确认协议
- [ ] 测试网络异常情况

#### Day 4: UI 和测试
- [ ] 添加消息状态显示
- [ ] 完整的端到端测试
- [ ] 性能优化

---

## 🔍 功能 2: 搜索增强

### 目标
提供快速、准确的全文搜索，支持高级过滤。

### 技术方案

#### 2.1 本地消息索引

**文件：** `HChat/Core/Search/MessageIndexer.swift`

```swift
import CoreSpotlight
import MobileCoreServices

@MainActor
class MessageIndexer {
    // 索引消息
    func index(message: ChatMessage) async throws {
        let attributeSet = CSSearchableItemAttributeSet(
            contentType: UTType.text
        )
        
        // 设置可搜索属性
        attributeSet.title = "\(message.sender) in #\(message.channel)"
        attributeSet.contentDescription = message.text
        attributeSet.keywords = extractKeywords(from: message.text)
        attributeSet.contentCreationDate = message.timestamp
        
        // 自定义属性
        attributeSet.setValue(message.channel, forCustomKey: "channel")
        attributeSet.setValue(message.sender, forCustomKey: "sender")
        
        let item = CSSearchableItem(
            uniqueIdentifier: message.id,
            domainIdentifier: "com.hchat.messages",
            attributeSet: attributeSet
        )
        
        try await CSSearchableIndex.default().indexSearchableItems([item])
    }
    
    // 提取关键词
    private func extractKeywords(from text: String) -> [String] {
        // 使用 NaturalLanguage 框架提取
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var keywords: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word) { tag, range in
            keywords.append(String(text[range]))
            return true
        }
        
        return keywords
    }
}
```

---

#### 2.2 高级搜索

**文件：** `HChat/Core/Search/MessageSearchEngine.swift`

```swift
@MainActor
@Observable
class MessageSearchEngine {
    private let persistence: MessagePersistence
    private let indexer: MessageIndexer
    
    // 搜索过滤器
    struct SearchFilters {
        var channels: [String] = []      // 指定频道
        var users: [String] = []         // 指定用户
        var dateRange: DateRange?        // 日期范围
        var hasAttachments: Bool?        // 是否有附件
        var fileTypes: [String] = []     // 文件类型
    }
    
    // 执行搜索
    func search(
        query: String,
        filters: SearchFilters = SearchFilters()
    ) async -> [ChatMessage] {
        // 1. Core Spotlight 搜索
        let spotlightResults = await searchSpotlight(query)
        
        // 2. 应用过滤器
        var results = spotlightResults
        
        if !filters.channels.isEmpty {
            results = results.filter { filters.channels.contains($0.channel) }
        }
        
        if !filters.users.isEmpty {
            results = results.filter { filters.users.contains($0.sender) }
        }
        
        if let dateRange = filters.dateRange {
            results = results.filter { 
                $0.timestamp >= dateRange.start && $0.timestamp <= dateRange.end 
            }
        }
        
        if let hasAttachments = filters.hasAttachments {
            results = results.filter { 
                hasAttachments ? !$0.attachments.isEmpty : $0.attachments.isEmpty 
            }
        }
        
        return results
    }
    
    // 搜索建议
    func suggestions(for prefix: String) async -> [String] {
        // 基于历史搜索和消息内容提供建议
        let recentSearches = getRecentSearches()
        let channelNames = getChannelNames()
        let userNames = getUserNames()
        
        return (recentSearches + channelNames + userNames)
            .filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
            .sorted()
            .prefix(5)
            .map { $0 }
    }
    
    // Spotlight 搜索实现
    private func searchSpotlight(_ query: String) async -> [ChatMessage] {
        // 实现 Core Spotlight 查询
        return []
    }
}
```

---

#### 2.3 搜索 UI

**文件：** `HChat/Views/Search/SearchView.swift`

```swift
struct SearchView: View {
    @State private var query = ""
    @State private var results: [ChatMessage] = []
    @State private var filters = MessageSearchEngine.SearchFilters()
    @State private var showFilters = false
    
    let searchEngine: MessageSearchEngine
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                SearchBar(text: $query, onSearch: performSearch)
                
                // 过滤器按钮
                FilterButton(active: hasActiveFilters) {
                    showFilters = true
                }
                
                // 结果列表
                List(results) { message in
                    SearchResultRow(message: message)
                        .onTapGesture {
                            // 跳转到消息位置
                            navigateToMessage(message)
                        }
                }
            }
            .navigationTitle("搜索")
            .sheet(isPresented: $showFilters) {
                SearchFiltersView(filters: $filters)
            }
        }
    }
    
    private func performSearch() {
        Task {
            results = await searchEngine.search(query: query, filters: filters)
        }
    }
    
    private var hasActiveFilters: Bool {
        !filters.channels.isEmpty || 
        !filters.users.isEmpty || 
        filters.dateRange != nil
    }
}
```

---

## 🔔 功能 3: 通知优化

### 目标
智能、友好的通知系统，减少打扰。

### 技术方案

#### 3.1 通知优先级

**文件：** `HChat/Core/Services/SmartNotificationManager.swift`

```swift
@MainActor
class SmartNotificationManager {
    // 通知优先级
    enum Priority {
        case urgent     // @mention、私聊、关键词
        case normal     // 普通频道消息
        case silent     // 静音频道
    }
    
    // 确定优先级
    func determinePriority(for message: ChatMessage, myNick: String) -> Priority {
        // 1. 私聊 = 紧急
        if message.channel.hasPrefix("pm/") {
            return .urgent
        }
        
        // 2. @提及 = 紧急
        if message.text.contains("@\(myNick)") {
            return .urgent
        }
        
        // 3. 关键词匹配 = 紧急
        if containsKeywords(message.text) {
            return .urgent
        }
        
        // 4. 静音频道 = 静音
        if isMutedChannel(message.channel) {
            return .silent
        }
        
        // 5. 其他 = 普通
        return .normal
    }
    
    // 是否应该通知
    func shouldNotify(message: ChatMessage, myNick: String) -> Bool {
        let priority = determinePriority(for: message, myNick: myNick)
        
        // 静音频道不通知
        if priority == .silent {
            return false
        }
        
        // 工作时间判断
        if isWorkingHours() {
            // 工作时间：只通知紧急消息
            return priority == .urgent
        } else {
            // 非工作时间：紧急消息通知，普通消息静默
            return priority == .urgent
        }
    }
    
    // 判断是否工作时间
    private func isWorkingHours() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date())
        
        // 周一到周五 9:00-18:00
        let isWeekday = (2...6).contains(weekday)
        let isDuringWork = (9...18).contains(hour)
        
        return isWeekday && isDuringWork
    }
    
    // 关键词匹配
    private func containsKeywords(_ text: String) -> Bool {
        let keywords = getUserKeywords() // 从设置获取
        return keywords.contains { text.lowercased().contains($0.lowercased()) }
    }
    
    // 静音频道检查
    private func isMutedChannel(_ channel: String) -> Bool {
        let mutedChannels = getMutedChannels() // 从设置获取
        return mutedChannels.contains(channel)
    }
}
```

---

#### 3.2 通知分组

**文件：** `HChat/Core/Services/NotificationGrouper.swift`

```swift
class NotificationGrouper {
    // 通知分组策略
    enum GroupStrategy {
        case byChannel    // 按频道分组
        case byTime       // 按时间分组
        case byPriority   // 按优先级分组
    }
    
    // 发送分组通知
    func sendGroupedNotification(
        messages: [ChatMessage],
        strategy: GroupStrategy
    ) async {
        switch strategy {
        case .byChannel:
            await groupByChannel(messages)
        case .byTime:
            await groupByTime(messages)
        case .byPriority:
            await groupByPriority(messages)
        }
    }
    
    // 按频道分组
    private func groupByChannel(_ messages: [ChatMessage]) async {
        let grouped = Dictionary(grouping: messages) { $0.channel }
        
        for (channel, msgs) in grouped {
            let content = UNMutableNotificationContent()
            content.title = "#\(channel)"
            content.body = "\(msgs.count) 条新消息"
            content.threadIdentifier = channel
            content.summaryArgument = channel
            content.summaryArgumentCount = msgs.count
            
            await sendNotification(content)
        }
    }
    
    // 发送通知
    private func sendNotification(_ content: UNMutableNotificationContent) async {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

---

#### 3.3 通知设置 UI

**文件：** `HChat/Views/Settings/NotificationSettingsView.swift`

```swift
struct NotificationSettingsView: View {
    @State private var enableNotifications = true
    @State private var urgentOnly = false
    @State private var keywords: [String] = []
    @State private var mutedChannels: [String] = []
    
    var body: some View {
        Form {
            // 基本设置
            Section("基本设置") {
                Toggle("启用通知", isOn: $enableNotifications)
                Toggle("仅紧急消息", isOn: $urgentOnly)
            }
            
            // 工作时间
            Section("工作时间（自动静音）") {
                DatePicker("开始", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                DatePicker("结束", selection: .constant(Date()), displayedComponents: .hourAndMinute)
            }
            
            // 关键词
            Section("关键词提醒") {
                ForEach(keywords, id: \.self) { keyword in
                    Text(keyword)
                }
                Button("添加关键词") {
                    // 添加关键词
                }
            }
            
            // 静音频道
            Section("静音频道") {
                ForEach(mutedChannels, id: \.self) { channel in
                    Text("#\(channel)")
                }
            }
        }
        .navigationTitle("通知设置")
    }
}
```

---

## 📊 测试计划

### 消息可靠性测试
```swift
class MessageReliabilityTests: XCTestCase {
    func testOfflineMessageQueue() async {
        // 模拟离线发送
        // 验证消息保存到队列
        // 验证重连后自动发送
    }
    
    func testMessageStatusTransition() async {
        // 验证状态转换：sending -> sent -> delivered -> read
    }
    
    func testRetryMechanism() async {
        // 验证失败重试逻辑
    }
}
```

### 搜索测试
```swift
class SearchTests: XCTestCase {
    func testFullTextSearch() async {
        // 测试全文搜索准确性
    }
    
    func testFilteredSearch() async {
        // 测试过滤器功能
    }
    
    func testSearchPerformance() {
        measure {
            // 测试搜索性能
        }
    }
}
```

### 通知测试
```swift
class NotificationTests: XCTestCase {
    func testPriorityDetection() {
        // 测试优先级判断
    }
    
    func testWorkingHoursLogic() {
        // 测试工作时间逻辑
    }
    
    func testNotificationGrouping() async {
        // 测试通知分组
    }
}
```

---

## 📈 性能指标

### 消息可靠性
- ✅ 消息送达率：> 99.9%
- ✅ 离线消息重发成功率：> 99%
- ✅ 状态更新延迟：< 100ms

### 搜索
- ✅ 搜索响应时间：< 200ms
- ✅ 索引更新延迟：< 500ms
- ✅ 内存占用：< 50MB

### 通知
- ✅ 通知延迟：< 1s
- ✅ 误报率：< 1%
- ✅ 电池影响：< 5%

---

## 🚀 发布计划

### 版本 1.1.0 - P0 功能完整版

**发布内容：**
- ✅ 消息可靠性（100% 送达保证）
- ✅ 增强搜索（全文索引 + 高级过滤）
- ✅ 智能通知（优先级 + 免打扰）

**发布检查清单：**
- [ ] 所有单元测试通过
- [ ] UI 测试通过
- [ ] 性能测试达标
- [ ] 文档更新
- [ ] 变更日志
- [ ] TestFlight 测试

---

**开始日期：** 2025-10-21  
**目标完成：** 2025-11-04（2周）

🚀 **Let's build something amazing!**

