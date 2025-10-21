//
//  ChatView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//
import SwiftUI

struct ChatView: View {
    @StateObject var client: HackChatClient
    @StateObject var callManager = CallManager()

    @State private var inputText: String = ""
    @State private var searchText: String = ""
    @State private var showCallSheet = false

//    let minio = MinIOService(baseApi: URL(string: "https://hc.go-lv.com")!)
//    lazy var uploader = UploadManager(minio: minio)
    let uploader = Services.uploader

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索/过滤
                TextField("搜索消息 / 过滤 @ 提及", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding([.top, .horizontal])

                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredMessages, id: \.id) { m in
                            MessageRowView(message: m, myNick: client.myNick)
                                .id(m.id)
                        }
                    }
                    .listStyle(.plain)
                }

                HStack(spacing: 8) {
                    Button {
                        showPhotoPicker()
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .buttonStyle(.borderless)

                    TextField("消息（支持 /join /nick /me /clear /help）", text: $inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit {
                            sendOnce()
                        }

                    Button("发送") { sendOnce() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
//            .navigationTitle("#\(client.currentChannel)")
//            .navigationTitle("#\(client.currentChannel)\( client.onlineByRoom[client.currentChannel].map { " · \($0.count) 在线" } ?? "" )")
            .navigationTitle("#\(client.currentChannel)\( client.onlineCountByRoom[client.currentChannel].map { " · \($0) 在线" } ?? "" )")

            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(client.channels) { ch in
                            Button("#\(ch.name)") { client.currentChannel = ch.name }
                        }
                        Divider()
                        Button("新建频道") { createChannelPrompt() }
                        Button("私聊…") { startPrivateChatPrompt() }
                    } label: {
                        Label("频道", systemImage: "number")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCallSheet = true
                    } label: {
                        Image(systemName: "phone.arrow.up.right") // ☎︎
                    }
                }
            }
            .sheet(isPresented: $showCallSheet) {
                #if canImport(LiveKit)
                CallView(roomName: client.currentChannel, identity: client.myNick)
                    .presentationDetents([.medium])
                #else
                Text("未集成 LiveKit")
                #endif
            }
            .onAppear { NotificationManager.shared.configure() }
        }
    }

    private var filteredMessages: [ChatMessage] {
        let all = client.messagesByChannel[client.currentChannel] ?? []
        guard !searchText.isEmpty else { return all }
        let key = searchText.lowercased()
        return all.filter { $0.text.lowercased().contains(key) || $0.sender.lowercased().contains(key) }
    }

    private func sendOnce() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        client.sendText(text)        // ✅ 只这一处触发发送，杜绝重复调用
        inputText = ""
    }

    private func showPhotoPicker() {
        // 你可换成系统 PhotosPicker，这里演示从剪贴板粘图
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
        // 简化：直接随机名
        let name = "room-\(Int.random(in: 100...999))"
        client.sendText("/join \(name)")
    }

    private func startPrivateChatPrompt() {
        // 简化：用 @someone 作为频道名（你的网关可映射成真正私聊）
        let pm = "pm-\(Int.random(in: 1000...9999))"
        client.sendText("/join \(pm)")
    }
}

