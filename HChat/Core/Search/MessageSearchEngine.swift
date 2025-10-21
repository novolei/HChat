//
//  MessageSearchEngine.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  消息搜索引擎 - 提供全文搜索和高级过滤
//

import Foundation
import Observation

/// 搜索过滤器
struct SearchFilters {
    var channels: [String] = []          // 指定频道
    var users: [String] = []             // 指定用户
    var dateRange: DateRange?            // 日期范围
    var hasAttachments: Bool?            // 是否有附件
    var attachmentTypes: [Attachment.Kind] = []  // 附件类型
    
    /// 日期范围
    struct DateRange {
        let start: Date
        let end: Date
    }
    
    /// 是否有活动的过滤器
    var hasActiveFilters: Bool {
        !channels.isEmpty || 
        !users.isEmpty || 
        dateRange != nil || 
        hasAttachments != nil ||
        !attachmentTypes.isEmpty
    }
}

@MainActor
@Observable
final class MessageSearchEngine {
    // MARK: - 依赖
    private weak var chatState: ChatState?
    
    // MARK: - 搜索结果
    var searchResults: [ChatMessage] = []
    var isSearching = false
    
    // MARK: - 搜索历史
    private let searchHistoryKey = "searchHistory"
    private let maxHistoryCount = 20
    
    var searchHistory: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: searchHistoryKey) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: searchHistoryKey)
        }
    }
    
    // MARK: - 初始化
    init(chatState: ChatState? = nil) {
        self.chatState = chatState
    }
    
    // MARK: - 公开方法
    
    /// 执行搜索
    func search(query: String, filters: SearchFilters = SearchFilters()) async {
        guard !query.isEmpty || filters.hasActiveFilters else {
            searchResults = []
            return
        }
        
        isSearching = true
        DebugLogger.log("🔍 开始搜索: \(query)", level: .info)
        
        // 保存到搜索历史
        if !query.isEmpty {
            addToHistory(query)
        }
        
        // 获取所有消息
        guard let state = chatState else {
            isSearching = false
            return
        }
        
        var allMessages: [ChatMessage] = []
        for (_, messages) in state.messagesByChannel {
            allMessages.append(contentsOf: messages)
        }
        
        // 应用搜索和过滤
        var results = allMessages
        
        // 1. 文本搜索
        if !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            results = results.filter { message in
                message.text.lowercased().contains(lowercasedQuery) ||
                message.sender.lowercased().contains(lowercasedQuery)
            }
        }
        
        // 2. 频道过滤
        if !filters.channels.isEmpty {
            results = results.filter { filters.channels.contains($0.channel) }
        }
        
        // 3. 用户过滤
        if !filters.users.isEmpty {
            results = results.filter { filters.users.contains($0.sender) }
        }
        
        // 4. 日期范围过滤
        if let dateRange = filters.dateRange {
            results = results.filter { 
                $0.timestamp >= dateRange.start && $0.timestamp <= dateRange.end 
            }
        }
        
        // 5. 附件过滤
        if let hasAttachments = filters.hasAttachments {
            results = results.filter { 
                hasAttachments ? !$0.attachments.isEmpty : $0.attachments.isEmpty 
            }
        }
        
        // 6. 附件类型过滤
        if !filters.attachmentTypes.isEmpty {
            results = results.filter { message in
                message.attachments.contains { attachment in
                    filters.attachmentTypes.contains(attachment.kind)
                }
            }
        }
        
        // 按时间倒序排列（最新的在前）
        results.sort { $0.timestamp > $1.timestamp }
        
        searchResults = results
        isSearching = false
        
        DebugLogger.log("🔍 搜索完成: 找到 \(results.count) 条结果", level: .info)
    }
    
    /// 清空搜索结果
    func clearResults() {
        searchResults = []
    }
    
    /// 获取搜索建议
    func suggestions(for prefix: String) -> [String] {
        guard !prefix.isEmpty else {
            return Array(searchHistory.prefix(5))
        }
        
        let lowercasedPrefix = prefix.lowercased()
        var suggestions = Set<String>()
        
        // 1. 从搜索历史中匹配
        for history in searchHistory {
            if history.lowercased().hasPrefix(lowercasedPrefix) {
                suggestions.insert(history)
            }
        }
        
        // 2. 从频道名中匹配
        if let state = chatState {
            for channel in state.channels {
                if channel.name.lowercased().hasPrefix(lowercasedPrefix) {
                    suggestions.insert("#\(channel.name)")
                }
            }
        }
        
        // 3. 从用户名中匹配
        if let state = chatState {
            for (_, users) in state.onlineByRoom {
                for user in users {
                    if user.lowercased().hasPrefix(lowercasedPrefix) {
                        suggestions.insert("@\(user)")
                    }
                }
            }
        }
        
        return Array(suggestions).sorted().prefix(5).map { $0 }
    }
    
    /// 清空搜索历史
    func clearHistory() {
        searchHistory = []
        DebugLogger.log("🗑️ 清空搜索历史", level: .info)
    }
    
    // MARK: - 私有方法
    
    /// 添加到搜索历史
    private func addToHistory(_ query: String) {
        var history = searchHistory
        
        // 移除重复项
        history.removeAll { $0 == query }
        
        // 添加到开头
        history.insert(query, at: 0)
        
        // 限制数量
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        searchHistory = history
    }
}

