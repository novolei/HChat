//
//  NotificationSettingsView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  通知设置界面
//

import SwiftUI

struct NotificationSettingsView: View {
    @State private var settings: SmartNotificationManager.Settings
    @State private var newKeyword = ""
    @State private var showAddKeyword = false
    
    let client: HackChatClient
    
    init(client: HackChatClient) {
        self.client = client
        self._settings = State(initialValue: SmartNotificationManager.shared.settings)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本设置
                Section("基本设置") {
                    Toggle("启用通知", isOn: $settings.enabled)
                    
                    if settings.enabled {
                        Toggle("仅紧急消息", isOn: $settings.urgentOnly)
                            .help("只通知 @提及、私聊和关键词匹配的消息")
                        
                        Toggle("按频道分组", isOn: $settings.groupByChannel)
                            .help("将同一频道的消息通知分组显示")
                    }
                }
                
                // 工作时间（免打扰）
                Section {
                    Toggle("启用工作时间免打扰", isOn: Binding(
                        get: { settings.workingHours?.enabled ?? false },
                        set: { newValue in
                            if settings.workingHours == nil {
                                settings.workingHours = SmartNotificationManager.Settings.WorkingHours()
                            }
                            settings.workingHours?.enabled = newValue
                        }
                    ))
                    
                    if settings.workingHours?.enabled == true {
                        Picker("开始时间", selection: Binding(
                            get: { settings.workingHours?.startHour ?? 9 },
                            set: { settings.workingHours?.startHour = $0 }
                        )) {
                            ForEach(0..<24) { hour in
                                Text(String(format: "%02d:00", hour))
                                    .tag(hour)
                            }
                        }
                        
                        Picker("结束时间", selection: Binding(
                            get: { settings.workingHours?.endHour ?? 18 },
                            set: { settings.workingHours?.endHour = $0 }
                        )) {
                            ForEach(0..<24) { hour in
                                Text(String(format: "%02d:00", hour))
                                    .tag(hour)
                            }
                        }
                        
                        Toggle("仅工作日", isOn: Binding(
                            get: { settings.workingHours?.weekdaysOnly ?? true },
                            set: { settings.workingHours?.weekdaysOnly = $0 }
                        ))
                        .help("周一到周五应用免打扰规则")
                    }
                } header: {
                    Text("工作时间（智能免打扰）")
                } footer: {
                    if settings.workingHours?.enabled == true {
                        Text("工作时间内只通知紧急消息（@提及、私聊、关键词）")
                            .font(.caption)
                    }
                }
                
                // 关键词提醒
                Section {
                    ForEach(settings.keywords, id: \.self) { keyword in
                        HStack {
                            Label(keyword, systemImage: "key")
                            Spacer()
                            Button {
                                settings.keywords.removeAll { $0 == keyword }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button {
                        showAddKeyword = true
                    } label: {
                        Label("添加关键词", systemImage: "plus.circle")
                    }
                } header: {
                    Text("关键词提醒")
                } footer: {
                    Text("包含关键词的消息将作为紧急通知")
                        .font(.caption)
                }
                
                // 静音频道
                Section {
                    ForEach(client.state.channels) { channel in
                        Toggle(isOn: Binding(
                            get: { settings.mutedChannels.contains(channel.name) },
                            set: { isMuted in
                                if isMuted {
                                    settings.mutedChannels.append(channel.name)
                                } else {
                                    settings.mutedChannels.removeAll { $0 == channel.name }
                                }
                            }
                        )) {
                            Label("#\(channel.name)", systemImage: "number")
                        }
                    }
                } header: {
                    Text("静音频道")
                } footer: {
                    Text("静音频道的消息不会发送通知")
                        .font(.caption)
                }
                
                // 测试通知
                Section {
                    Button {
                        sendTestNotification()
                    } label: {
                        Label("发送测试通知", systemImage: "bell.badge")
                    }
                } header: {
                    Text("测试")
                }
            }
            .navigationTitle("通知设置")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: settings) { _, newSettings in
                SmartNotificationManager.shared.settings = newSettings
            }
            .alert("添加关键词", isPresented: $showAddKeyword) {
                TextField("关键词", text: $newKeyword)
                Button("添加") {
                    if !newKeyword.isEmpty {
                        settings.keywords.append(newKeyword)
                        newKeyword = ""
                    }
                }
                Button("取消", role: .cancel) {
                    newKeyword = ""
                }
            } message: {
                Text("输入你想要关注的关键词")
            }
        }
    }
    
    // MARK: - 方法
    
    private func sendTestNotification() {
        Task {
            let content = UNMutableNotificationContent()
            content.title = "HChat 测试通知"
            content.body = "通知功能正常工作！👍"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

// MARK: - 预览

#Preview {
    NotificationSettingsView(client: HackChatClient())
}

