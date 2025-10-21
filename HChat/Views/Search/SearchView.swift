//
//  SearchView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  搜索界面
//

import SwiftUI

struct SearchView: View {
    let client: HackChatClient
    
    @State private var searchEngine: MessageSearchEngine
    @State private var query = ""
    @State private var filters = SearchFilters()
    @State private var showFilters = false
    @State private var suggestions: [String] = []
    @State private var showSuggestions = false
    
    init(client: HackChatClient) {
        self.client = client
        self._searchEngine = State(initialValue: MessageSearchEngine(chatState: client.state))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                searchBar
                
                // 搜索建议
                if showSuggestions && !suggestions.isEmpty {
                    suggestionsList
                }
                
                // 搜索结果
                if searchEngine.isSearching {
                    ProgressView("搜索中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if query.isEmpty && !filters.hasActiveFilters {
                    emptyState
                } else if searchEngine.searchResults.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("搜索消息")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Label("过滤器", systemImage: filters.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(filters.hasActiveFilters ? .blue : .primary)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersView(filters: $filters, client: client)
            }
        }
    }
    
    // MARK: - 子视图
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索消息、@用户、#频道", text: $query)
                .textFieldStyle(.plain)
                .onChange(of: query) { _, newValue in
                    updateSuggestions(for: newValue)
                    if !newValue.isEmpty || filters.hasActiveFilters {
                        performSearch()
                    } else {
                        searchEngine.clearResults()
                    }
                }
                .onSubmit {
                    showSuggestions = false
                    performSearch()
                }
            
            if !query.isEmpty {
                Button {
                    query = ""
                    searchEngine.clearResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var suggestionsList: some View {
        List {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    query = suggestion
                    showSuggestions = false
                    performSearch()
                } label: {
                    HStack {
                        Image(systemName: suggestion.hasPrefix("#") ? "number" : suggestion.hasPrefix("@") ? "at" : "clock")
                            .foregroundColor(.secondary)
                        Text(suggestion)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .frame(maxHeight: 200)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("搜索消息")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("输入关键词、@用户名或#频道名")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 搜索历史
            if !searchEngine.searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("最近搜索")
                            .font(.headline)
                        Spacer()
                        Button("清空") {
                            searchEngine.clearHistory()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(searchEngine.searchHistory.prefix(10), id: \.self) { history in
                                Button {
                                    query = history
                                    performSearch()
                                } label: {
                                    Text(history)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("未找到结果")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("试试修改搜索词或调整过滤器")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsList: some View {
        VStack(spacing: 0) {
            // 结果统计
            HStack {
                Text("找到 \(searchEngine.searchResults.count) 条结果")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if filters.hasActiveFilters {
                    Button {
                        filters = SearchFilters()
                        performSearch()
                    } label: {
                        Text("清除过滤器")
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // 结果列表
            List(searchEngine.searchResults) { message in
                SearchResultRow(message: message, query: query)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 跳转到消息所在频道
                        navigateToMessage(message)
                    }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - 方法
    
    private func updateSuggestions(for text: String) {
        if text.isEmpty {
            suggestions = Array(searchEngine.searchHistory.prefix(5))
            showSuggestions = !suggestions.isEmpty
        } else {
            suggestions = searchEngine.suggestions(for: text)
            showSuggestions = !suggestions.isEmpty
        }
    }
    
    private func performSearch() {
        Task {
            await searchEngine.search(query: query, filters: filters)
        }
    }
    
    private func navigateToMessage(_ message: ChatMessage) {
        // 切换到消息所在频道
        client.state.currentChannel = message.channel
        // 关闭搜索界面（由父视图处理）
    }
}

// MARK: - 搜索结果行

struct SearchResultRow: View {
    let message: ChatMessage
    let query: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 频道和时间
            HStack {
                Label("#\(message.channel)", systemImage: "number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 发送者
            Text(message.sender)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // 消息内容（高亮搜索词）
            if !message.text.isEmpty {
                Text(highlightedText(message.text))
                    .lineLimit(3)
            }
            
            // 附件
            if !message.attachments.isEmpty {
                HStack {
                    ForEach(message.attachments) { attachment in
                        Label(attachment.filename, systemImage: iconForAttachment(attachment.kind))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        
        if !query.isEmpty, let range = attributed.range(of: query, options: .caseInsensitive) {
            attributed[range].backgroundColor = .yellow
            attributed[range].foregroundColor = .black
        }
        
        return attributed
    }
    
    private func iconForAttachment(_ kind: Attachment.Kind) -> String {
        switch kind {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .file: return "doc"
        }
    }
}

// MARK: - 预览

#Preview {
    SearchView(client: HackChatClient())
}

