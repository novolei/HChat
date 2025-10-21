//
//  SearchFiltersView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  搜索过滤器设置界面
//

import SwiftUI

struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    let client: HackChatClient
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedChannels: Set<String> = []
    @State private var selectedUsers: Set<String> = []
    @State private var hasAttachments: Bool? = nil
    @State private var selectedAttachmentTypes: Set<Attachment.Kind> = []
    @State private var dateRangeEnabled = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                // 频道过滤
                Section("频道") {
                    if client.state.channels.isEmpty {
                        Text("暂无频道")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(client.state.channels) { channel in
                            Toggle(isOn: Binding(
                                get: { selectedChannels.contains(channel.name) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedChannels.insert(channel.name)
                                    } else {
                                        selectedChannels.remove(channel.name)
                                    }
                                }
                            )) {
                                Label("#\(channel.name)", systemImage: "number")
                            }
                        }
                    }
                }
                
                // 用户过滤
                Section("用户") {
                    if allUsers.isEmpty {
                        Text("暂无用户")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(allUsers).sorted(), id: \.self) { user in
                            Toggle(isOn: Binding(
                                get: { selectedUsers.contains(user) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedUsers.insert(user)
                                    } else {
                                        selectedUsers.remove(user)
                                    }
                                }
                            )) {
                                Label("@\(user)", systemImage: "at")
                            }
                        }
                    }
                }
                
                // 附件过滤
                Section("附件") {
                    Picker("附件状态", selection: $hasAttachments) {
                        Text("全部").tag(nil as Bool?)
                        Text("仅有附件").tag(true as Bool?)
                        Text("无附件").tag(false as Bool?)
                    }
                    
                    if hasAttachments == true {
                        Toggle("图片", isOn: Binding(
                            get: { selectedAttachmentTypes.contains(.image) },
                            set: { if $0 { selectedAttachmentTypes.insert(.image) } else { selectedAttachmentTypes.remove(.image) } }
                        ))
                        
                        Toggle("视频", isOn: Binding(
                            get: { selectedAttachmentTypes.contains(.video) },
                            set: { if $0 { selectedAttachmentTypes.insert(.video) } else { selectedAttachmentTypes.remove(.video) } }
                        ))
                        
                        Toggle("音频", isOn: Binding(
                            get: { selectedAttachmentTypes.contains(.audio) },
                            set: { if $0 { selectedAttachmentTypes.insert(.audio) } else { selectedAttachmentTypes.remove(.audio) } }
                        ))
                        
                        Toggle("文件", isOn: Binding(
                            get: { selectedAttachmentTypes.contains(.file) },
                            set: { if $0 { selectedAttachmentTypes.insert(.file) } else { selectedAttachmentTypes.remove(.file) } }
                        ))
                    }
                }
                
                // 日期范围
                Section("日期范围") {
                    Toggle("启用日期过滤", isOn: $dateRangeEnabled)
                    
                    if dateRangeEnabled {
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("搜索过滤器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        applyFilters()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button("重置全部") {
                        resetFilters()
                    }
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var allUsers: Set<String> {
        var users = Set<String>()
        for (_, userSet) in client.state.onlineByRoom {
            users.formUnion(userSet)
        }
        return users
    }
    
    // MARK: - 方法
    
    private func loadCurrentFilters() {
        selectedChannels = Set(filters.channels)
        selectedUsers = Set(filters.users)
        hasAttachments = filters.hasAttachments
        selectedAttachmentTypes = Set(filters.attachmentTypes)
        
        if let dateRange = filters.dateRange {
            dateRangeEnabled = true
            startDate = dateRange.start
            endDate = dateRange.end
        }
    }
    
    private func applyFilters() {
        filters.channels = Array(selectedChannels)
        filters.users = Array(selectedUsers)
        filters.hasAttachments = hasAttachments
        filters.attachmentTypes = Array(selectedAttachmentTypes)
        
        if dateRangeEnabled {
            filters.dateRange = SearchFilters.DateRange(start: startDate, end: endDate)
        } else {
            filters.dateRange = nil
        }
    }
    
    private func resetFilters() {
        selectedChannels = []
        selectedUsers = []
        hasAttachments = nil
        selectedAttachmentTypes = []
        dateRangeEnabled = false
        startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        endDate = Date()
    }
}

// MARK: - 预览

#Preview {
    @Previewable @State var filters = SearchFilters()
    SearchFiltersView(filters: $filters, client: HackChatClient())
}

