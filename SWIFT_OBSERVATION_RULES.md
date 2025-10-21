# 📘 Swift Observation API 使用规则

本文档定义 HChat 项目中使用 Swift 现代 Observation API 的规范和最佳实践。

**适用版本：** iOS 17+ / macOS 14+ / Swift 5.9+

---

## 🎯 核心原则

### ✅ 使用 `@Observable` 宏（推荐）

自 iOS 17 / Swift 5.9 起，使用 `@Observable` 宏替代传统的 `ObservableObject` 协议。

**优势：**
- ✨ 更简洁的语法（无需 `@Published`）
- ⚡️ 更高的性能（细粒度观察）
- 🔍 更好的类型推断
- 🛡️ 编译时安全检查

### ❌ 避免使用旧 API

**不再使用：**
- ~~`ObservableObject` 协议~~
- ~~`@Published` 属性包装器~~
- ~~`@StateObject` 属性包装器~~
- ~~`@ObservedObject` 属性包装器~~
- ~~`import Combine`（仅用于观察）~~

---

## 📋 规则详解

### 规则 1: 模型类使用 `@Observable` 宏

**✅ 正确示例：**

```swift
import Foundation
import Observation  // ✅ 导入 Observation 框架

@MainActor
@Observable
final class ChatClient {
    // ✅ 直接声明属性，无需 @Published
    var messages: [Message] = []
    var isConnected: Bool = false
    var nickname: String = "User"
    
    // ✅ 私有属性自动不被观察
    private var webSocket: URLSessionWebSocketTask?
    
    func sendMessage(_ text: String) {
        // 自动触发 UI 更新
        messages.append(Message(text: text))
    }
}
```

**❌ 错误示例（旧方式）：**

```swift
import Combine  // ❌ 不再需要

@MainActor
final class ChatClient: ObservableObject {  // ❌ 使用旧 API
    @Published var messages: [Message] = []  // ❌ 不再需要 @Published
    @Published var isConnected: Bool = false
    
    private var cancellables = Set<AnyCancellable>()  // ❌ 不再需要
}
```

---

### 规则 2: App 入口使用 `@State`

**✅ 正确示例：**

```swift
import SwiftUI

@main
struct MyApp: App {
    @State var client = ChatClient()  // ✅ 使用 @State
    
    var body: some Scene {
        WindowGroup {
            ContentView(client: client)
        }
    }
}
```

**❌ 错误示例：**

```swift
@main
struct MyApp: App {
    @StateObject var client = ChatClient()  // ❌ 旧 API
}
```

---

### 规则 3: 子视图直接声明属性（无包装器）

**✅ 正确示例：**

```swift
import SwiftUI

struct ChatView: View {
    var client: ChatClient  // ✅ 无需属性包装器
    @State var inputText = ""  // ✅ 局部状态仍用 @State
    
    var body: some View {
        VStack {
            // ✅ 自动观察 client 的变化
            Text("消息数: \(client.messages.count)")
            TextField("输入", text: $inputText)
        }
    }
}
```

**❌ 错误示例：**

```swift
struct ChatView: View {
    @ObservedObject var client: ChatClient  // ❌ 旧 API
    @StateObject var client: ChatClient     // ❌ 也不对
}
```

---

### 规则 4: 需要绑定时使用 `@Bindable`

当需要对 `@Observable` 对象的属性创建双向绑定时，使用 `@Bindable`。

**✅ 正确示例：**

```swift
struct SettingsView: View {
    @Bindable var client: ChatClient  // ✅ 支持 $ 绑定
    
    var body: some View {
        Form {
            // ✅ 可以使用 $ 创建绑定
            TextField("昵称", text: $client.nickname)
            Toggle("已连接", isOn: $client.isConnected)
        }
    }
}
```

**何时使用 `@Bindable`：**
- ✅ 需要 `$` 绑定传递给子组件
- ✅ 使用 `TextField`, `Toggle`, `Slider` 等需要绑定的控件
- ❌ 仅读取属性时不需要（直接用 `var` 即可）

---

### 规则 5: 局部状态仍用 `@State`

视图的私有状态继续使用 `@State`，这与 `@Observable` 无关。

**✅ 正确示例：**

```swift
struct ChatView: View {
    var client: ChatClient           // ✅ Observable 对象
    @State private var inputText = "" // ✅ 局部状态
    @State private var showSheet = false
    
    var body: some View {
        VStack {
            TextField("消息", text: $inputText)
                .onSubmit { 
                    client.sendMessage(inputText)
                    inputText = ""
                }
        }
    }
}
```

---

### 规则 6: 与 `@MainActor` 配合使用

对于需要在主线程更新的模型，结合 `@MainActor` 使用。

**✅ 正确示例：**

```swift
@MainActor
@Observable
final class ChatClient {
    var messages: [Message] = []
    
    // ✅ 自动在主线程执行
    func connect() {
        // WebSocket 连接...
        messages.append(Message(text: "已连接"))
    }
}
```

**何时使用 `@MainActor`：**
- ✅ UI 相关的模型类（如 ViewModel）
- ✅ 需要频繁更新 UI 的数据
- ❌ 纯数据模型或后台处理类

---

## 🔄 迁移指南

### 从 ObservableObject 迁移到 @Observable

#### 步骤 1: 更新导入
```swift
// ❌ 移除
import Combine

// ✅ 添加
import Observation
```

#### 步骤 2: 更新类声明
```swift
// ❌ 旧方式
final class MyModel: ObservableObject {

// ✅ 新方式
@Observable
final class MyModel {
```

#### 步骤 3: 移除 @Published
```swift
// ❌ 旧方式
@Published var count: Int = 0
@Published var name: String = ""

// ✅ 新方式
var count: Int = 0
var name: String = ""
```

#### 步骤 4: 移除 Combine 相关代码
```swift
// ❌ 移除
private var cancellables = Set<AnyCancellable>()
```

#### 步骤 5: 更新视图
```swift
// ❌ 旧方式
struct MyView: View {
    @StateObject var model = MyModel()
    @ObservedObject var sharedModel: MyModel
}

// ✅ 新方式
struct MyView: View {
    @State var model = MyModel()
    var sharedModel: MyModel
}
```

---

## 📊 对比表

| 场景 | 旧 API | 新 API (iOS 17+) |
|-----|--------|-----------------|
| 定义可观察类 | `class MyModel: ObservableObject` | `@Observable class MyModel` |
| 可观察属性 | `@Published var name: String` | `var name: String` |
| App 拥有对象 | `@StateObject var model = ...` | `@State var model = ...` |
| 子视图接收对象 | `@ObservedObject var model: ...` | `var model: ...` |
| 需要绑定 | `@ObservedObject var model: ...` + `$model.prop` | `@Bindable var model: ...` + `$model.prop` |
| 导入框架 | `import Combine` | `import Observation` |

---

## ✅ HChat 项目实践

### 已迁移的类

#### 1. HackChatClient
```swift
@MainActor
@Observable
final class HackChatClient {
    var channels: [Channel] = []
    var currentChannel: String = "lobby"
    var messagesByChannel: [String: [ChatMessage]] = [:]
    var myNick: String = "iOSUser"
    // ... 其他属性
}
```

#### 2. CallManager
```swift
@MainActor
@Observable
final class CallManager {
    var room: Room = Room()
    var isConnected: Bool = false
    var statusText: String = "未连接"
    var lastError: String?
}
```

### 视图使用示例

#### App 入口
```swift
@main
struct HChatApp: App {
    @State var client = HackChatClient()  // ✅ 使用 @State
    
    var body: some Scene {
        WindowGroup {
            ChatView(client: client)
        }
    }
}
```

#### 子视图
```swift
struct ChatView: View {
    var client: HackChatClient           // ✅ 无包装器
    @State var callManager = CallManager() // ✅ 局部拥有用 @State
    @State private var inputText = ""     // ✅ 局部状态
    
    var body: some View {
        List(client.messages) { message in
            Text(message.text)
        }
    }
}
```

---

## 🚨 常见错误

### 错误 1: 混用新旧 API

**❌ 错误：**
```swift
@Observable
final class MyModel {
    @Published var count: Int = 0  // ❌ @Observable 中不能用 @Published
}
```

**✅ 正确：**
```swift
@Observable
final class MyModel {
    var count: Int = 0  // ✅ 直接声明
}
```

---

### 错误 2: 在子视图中使用 @State 接收传入对象

**❌ 错误：**
```swift
struct ChildView: View {
    @State var model: MyModel  // ❌ 会创建新实例或丢失外部引用
}
```

**✅ 正确：**
```swift
struct ChildView: View {
    var model: MyModel  // ✅ 直接接收
}
```

---

### 错误 3: 忘记添加 @MainActor

如果模型在后台线程更新 UI 属性，会导致崩溃。

**❌ 错误：**
```swift
@Observable
final class MyModel {  // ❌ 缺少 @MainActor
    var count: Int = 0
    
    func fetchData() {
        Task {
            // 后台线程更新
            self.count = 10  // ❌ 可能在非主线程
        }
    }
}
```

**✅ 正确：**
```swift
@MainActor
@Observable
final class MyModel {  // ✅ 添加 @MainActor
    var count: Int = 0
    
    func fetchData() {
        Task { @MainActor in
            self.count = 10  // ✅ 保证在主线程
        }
    }
}
```

---

## 🔧 调试技巧

### 1. 验证观察是否生效

在属性的 `didSet` 中添加日志：
```swift
@Observable
final class MyModel {
    var count: Int = 0 {
        didSet {
            print("✅ count 更新: \(oldValue) → \(count)")
        }
    }
}
```

### 2. 检查是否在主线程

```swift
@MainActor
@Observable
final class MyModel {
    func updateUI() {
        assert(Thread.isMainThread, "❌ 必须在主线程调用")
        // ...
    }
}
```

---

## 📚 参考资源

- [Apple 官方文档 - Observation](https://developer.apple.com/documentation/observation)
- [WWDC23 - Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [Swift Evolution - SE-0395 Observation](https://github.com/apple/swift-evolution/blob/main/proposals/0395-observability.md)

---

## ✅ 检查清单

在提交代码前，确保：

- [ ] 所有 ViewModel/Model 类使用 `@Observable` 宏
- [ ] 移除所有 `@Published` 属性包装器
- [ ] App 入口使用 `@State` 而非 `@StateObject`
- [ ] 子视图接收对象时无属性包装器（或使用 `@Bindable`）
- [ ] 移除不必要的 `import Combine`
- [ ] UI 相关类添加 `@MainActor` 隔离
- [ ] 编译无警告和错误
- [ ] 运行时无 MainActor 断言失败

---

**记住：使用 @Observable 是 HChat 项目的强制规范！** 🚀

