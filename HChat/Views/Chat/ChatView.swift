//
//  ChatView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  重构版本：主视图协调器
//

import SwiftUI
import Combine
import Observation

@Observable
final class ChatBackgroundModel {
    private let storageKey = "chatBackgroundStyle"
    var style: ChatBackgroundStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: storageKey) }
    }
    
    init() {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ChatBackgroundStyle.dawn.rawValue
        self.style = ChatBackgroundStyle(rawValue: raw) ?? .dawn
    }
}

enum ChatBackgroundStyle: String, CaseIterable, Identifiable {
    case dawn, dusk, twilight, meadow
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .dawn: return "晨曦渐层"
        case .dusk: return "黄昏粉紫"
        case .twilight: return "星空夜色"
        case .meadow: return "萤光草地"
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .dawn: return ModernTheme.dawnGradient
        case .dusk: return ModernTheme.duskGradient
        case .twilight: return ModernTheme.twilightGradient
        case .meadow: return ModernTheme.meadowGradient
        }
    }
}

struct ChatView: View {
    var client: HackChatClient
    var onBack: (() -> Void)? = nil
    @State private var backgroundModel = ChatBackgroundModel()
    @State var callManager = CallManager()
    
    @State private var inputText: String = ""
    @State private var searchText: String = ""
    @State private var showCallSheet = false
    @State private var showNicknamePrompt = false
    @State private var nicknameInput: String = ""
    @State private var showStatusPicker = false
    @State private var showOnlineUsers = false
    @State private var wallpaperToast: ToastMessage? = nil
    
    let uploader = Services.uploader
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundModel.style.gradient
                    .ignoresSafeArea()
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ConnectionStatusBanner(
                        status: client.connectionStatus,
                        onReconnect: {
                            client.reconnect()
                        }
                    )

                    header
                        .padding(.horizontal, ModernTheme.spacing4)
                        .padding(.top, ModernTheme.spacing2)
                        .padding(.bottom, ModernTheme.spacing2)

                    ChatMessageListView(client: client, searchText: $searchText)
                        .padding(.bottom, ModernTheme.spacing4)
                        .transition(.opacity)

                    ChatInputView(
                        client: client,
                        inputText: $inputText,
                        onSend: sendOnce,
                        onAttachment: showPhotoPicker
                    )
                }
            }
            .contentShape(Rectangle())
            .hideKeyboardOnTapAndDrag()
            .navigationBarHidden(true)
            .toast($wallpaperToast)
            .sheet(isPresented: $showCallSheet) {
                VStack(spacing: 20) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 48))
                        .foregroundColor(HChatTheme.accent)
                    Text("语音通话功能开发中...")
                        .font(HChatTheme.bodyFont)
                        .foregroundColor(HChatTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium])
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
                if client.shouldShowNicknamePrompt {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showNicknamePrompt = true
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack(alignment: .center, spacing: ModernTheme.spacing4) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ModernTheme.primaryText)
                    .padding(10)
                    .background(
                        Circle().fill(Color.white.opacity(0.25))
                            .blur(radius: 10)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(client.currentChannel)")
                    .font(ModernTheme.title3)
                    .foregroundColor(ModernTheme.primaryText)
                Text("共有 \(client.onlineCountByRoom[client.currentChannel] ?? 0) 人在线")
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Menu {
                Section("背景主题") {
                    ForEach(ChatBackgroundStyle.allCases) { style in
                        Button {
                            if backgroundModel.style != style {
                                backgroundModel.style = style
                                wallpaperToast = ToastMessage(text: "聊天背景已更新", icon: "photo.on.rectangle")
                            }
                        } label: {
                            Label(style.title, systemImage: backgroundModel.style == style ? "checkmark" : "")
                        }
                    }
                }
                Section("功能") {
                    Button {
                        nicknameInput = client.myNick
                        showNicknamePrompt = true
                    } label: {
                        Label("修改昵称", systemImage: "person.circle")
                    }
                    Button {
                        showStatusPicker = true
                    } label: {
                        Label("设置状态", systemImage: "figure.wave")
                    }
                    Button {
                        showOnlineUsers = true
                    } label: {
                        Label("在线用户", systemImage: "person.2")
                    }
                    Button {
                        showCallSheet = true
                    } label: {
                        Label("发起语音通话", systemImage: "phone.arrow.up.right")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ModernTheme.primaryText)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.25)).blur(radius: 10))
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            }
        }
        .padding(.vertical, ModernTheme.spacing2)
        .glassSurface(cornerRadius: ModernTheme.extraLargeRadius, opacity: 0.45)
    }
    
    private func sendOnce() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if client.replyManager.replyingTo != nil {
            client.replyManager.sendReply(text: text)
        } else {
            client.sendText(text)
        }
        inputText = ""
    }
    
    private func showPhotoPicker() {
        if let img = UIPasteboard.general.image, let data = img.pngData() {
            Task {
                do {
                    let att = try await uploader.prepareImageAttachment(data, filename: "image.png")
                    client.sendAttachment(att)
                } catch {
                    DebugLogger.log("❌ 附件上传失败: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
}

