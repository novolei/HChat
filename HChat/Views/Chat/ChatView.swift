//
//  ChatView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  重构版本：主视图协调器
//

import SwiftUI

struct ChatView: View {
    var client: HackChatClient
    @State var callManager = CallManager()
    
    @State private var inputText: String = ""
    @State private var searchText: String = ""
    @State private var showCallSheet = false
    @State private var showNicknamePrompt = false
    @State private var nicknameInput: String = ""
    @State private var showStatusPicker = false
    @State private var showOnlineUsers = false
    
    let uploader = Services.uploader
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 聊天背景
                HChatTheme.chatBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 消息列表
                    ChatMessageListView(client: client, searchText: $searchText)
                    
                    // 输入框
                    ChatInputView(
                        client: client,
                        inputText: $inputText,
                        onSend: sendOnce,
                        onAttachment: showPhotoPicker
                    )
                }
            }
            .navigationTitle("#\(client.currentChannel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HChatTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ChatToolbar(
                    client: client,
                    showNicknamePrompt: $showNicknamePrompt,
                    nicknameInput: $nicknameInput,
                    showCallSheet: $showCallSheet,
                    showStatusPicker: $showStatusPicker,
                    showOnlineUsers: $showOnlineUsers,
                    onCreateChannel: createChannelPrompt,
                    onStartPrivateChat: startPrivateChatPrompt
                )
            }
            .sheet(isPresented: $showCallSheet) {
                #if canImport(LiveKit)
                CallView(roomName: client.currentChannel, identity: client.myNick)
                    .presentationDetents([.medium])
                #else
                Text("未集成 LiveKit")
                #endif
            }
            .sheet(isPresented: $showStatusPicker) {
                StatusPickerView(
                    currentStatus: Binding(
                        get: { client.presenceManager.myStatus },
                        set: { _ in }
                    ),
                    onStatusChange: { newStatus in
                        client.presenceManager.updateMyStatus(newStatus)
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showOnlineUsers) {
                OnlineUsersView(client: client)
                    .presentationDetents([.medium, .large])
            }
            .alert("设置您的昵称", isPresented: $showNicknamePrompt) {
                TextField("输入昵称", text: $nicknameInput)
                Button("确定") {
                    if !nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        client.changeNick(nicknameInput)
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("欢迎使用 HChat！请设置一个昵称，其他用户将看到这个名字。")
            }
            .onAppear {
                NotificationManager.shared.configure()
                
                // 首次启动时提示设置昵称
                if client.shouldShowNicknamePrompt {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showNicknamePrompt = true
                    }
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func sendOnce() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // ✨ P1: 如果正在回复，使用 ReplyManager 发送
        if client.replyManager.replyingTo != nil {
            client.replyManager.sendReply(text: text)
        } else {
            client.sendText(text)
        }
        
        inputText = ""
    }
    
    private func showPhotoPicker() {
        // 从剪贴板粘图（可替换为系统 PhotosPicker）
        if let img = UIPasteboard.general.image, let data = img.pngData() {
            Task {
                do {
                    let att = try await uploader.prepareImageAttachment(data, filename: "image.png")
                    client.sendAttachment(att)
                } catch {
                    print("upload error:", error.localizedDescription)
                }
            }
        }
    }
    
    private func createChannelPrompt() {
        let name = "room-\(Int.random(in: 100...999))"
        client.sendText("/join \(name)")
    }
    
    private func startPrivateChatPrompt() {
        let pm = "pm-\(Int.random(in: 1000...9999))"
        client.sendText("/join \(pm)")
    }
}
