//
//  ChatCoordinatorView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import LiveKit

//struct ChatCoordinatorView: View {
//    @StateObject private var vm = HackChatClient(
//        serverURLString: "wss://hc.go-lv.com/chat-ws",
//        defaultChannelName: "ios-dev",
//        nickname: "yourname#secret"
//    )
//    
//    @State private var showCallSheet = false
//
//    @State private var draft: String = ""
//    @State private var selectedPhotoItem: PhotosPickerItem?
//    @State private var showFileImporter = false
//    @State private var tsStyleRaw: Int = TimestampStyle.relative.rawValue
//    private var tsStyle: TimestampStyle { TimestampStyle(rawValue: tsStyleRaw) ?? .relative }
//
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                HackTheme.background.ignoresSafeArea()
//                VStack(spacing: 0) {
//                    header
//                    Divider().overlay(HackTheme.panelStroke).padding(.bottom, 6)
//                    chatScroll
//                    inputBar
//                        .padding(.horizontal, 12).padding(.vertical, 10)
//                        .background(.ultraThinMaterial)
//                        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(HackTheme.panelStroke), alignment: .top)
//                }
//            }
//            .toolbar {
//                ToolbarItem(placement: .topBarLeading) { channelMenu }
//                ToolbarItem(placement: .topBarTrailing) { connectButton }
//                ToolbarItem(placement: .topBarTrailing) { timestampMenu }
//                ToolbarItem(placement: .topBarTrailing) { notifyToggle }
//                #if canImport(LiveKit)
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button { showCallSheet = true } label: { Image(systemName: "phone.fill") }
//                }
//                #endif
//            }
//            .navigationTitle(vm.currentChannel.displayName)
//            .navigationBarTitleDisplayMode(.inline)
//            .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索消息")
//        }
//        .tint(.mint)
//        .onChange(of: selectedPhotoItem) { _, item in
//            guard let item else { return }
//            Task { await handlePhotoPicked(item) }
//        }
//        #if canImport(LiveKit)
//        .sheet(isPresented: $showCallSheet) {
//            CallView(roomName: vm.currentChannel.name, identity: vm.nickname.hcBaseNick)
//                .presentationDetents([.medium, .large])
//        }
//        #endif
//
//    }
//
//    // MARK: Header
//
//    private var header: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack(spacing: 8) {
//                TextField("昵称（可含 #口令）", text: $vm.nickname)
//                    .onSubmit { vm.sendChat(userInput: "/nick \(vm.nickname)") }
//                    .textFieldStyle(CapsuleFieldStyle())
//                Toggle("E2EE", isOn: $vm.isEndToEndEncryptionEnabled).toggleStyle(SwitchToggleStyle(tint: .mint))
//                if vm.isEndToEndEncryptionEnabled {
//                    SecureField("群口令", text: $vm.passphraseForEndToEndEncryption)
//                        .onSubmit { vm.sendChat(userInput: "/nick \(vm.nickname.hcBaseNick)#\(vm.passphraseForEndToEndEncryption)") }
//                        .textFieldStyle(CapsuleFieldStyle())
//                }
//                Spacer(minLength: 0)
//                Toggle("仅看 @我", isOn: $vm.showOnlyMentions).toggleStyle(SwitchToggleStyle(tint: .mint))
//            }
//        }
//        .padding(12)
//        .background(HackTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
//        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HackTheme.panelStroke))
//        .padding(.horizontal, 12).padding(.top, 8)
//    }
//
//    private var chatScroll: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 10) {
//                    ForEach(filtered()) { msg in
//                        MessageRowView(message: msg, myBaseNick: vm.nickname.hcBaseNick, tsStyle: tsStyle)
//                            .id(msg.id)
//                    }
//                }
//                .padding(.horizontal, 12).padding(.bottom, 8)
//            }
//            .onReceive(vm.$messages) { _ in
//                if let last = filtered().last {
//                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
//                }
//            }
//        }
//    }
//
//    private func filtered() -> [ChatMessage] {
//        let q = vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
//        return vm.messages.filter { m in
//            let passQ = q.isEmpty || m.plaintext.localizedCaseInsensitiveContains(q) || (m.attachment?.fileName?.localizedCaseInsensitiveContains(q) ?? false)
//            let passM = !vm.showOnlyMentions || m.plaintext.localizedCaseInsensitiveContains("@\(vm.nickname.hcBaseNick)")
//            return passQ && passM
//        }
//    }
//
//    private var inputBar: some View {
//        HStack(spacing: 10) {
//            PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .videos])) {
//                Image(systemName: "paperclip.circle.fill").imageScale(.large)
//            }
//            .buttonStyle(.plain)
//
//            Button { showFileImporter = true } label: { Image(systemName: "folder.circle.fill").imageScale(.large) }
//            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.data], allowsMultipleSelection: false) { r in
//                guard case .success(let urls) = r, let url = urls.first else { return }
//                Task { await handleFilePicked(url: url) }
//            }
//
//            TextField("消息…（/join /nick /dm /me /clear /help）", text: $draft, axis: .vertical)
//                .textFieldStyle(CapsuleFieldStyle())
//                .onSubmit(send)
//
//            Button(action: send) { Label("发送", systemImage: "arrow.up.circle.fill").labelStyle(.titleAndIcon) }
//                .buttonStyle(.borderedProminent).controlSize(.large)
//                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.connectionState != .connected)
//        }
//        .padding(.horizontal, 12)
//    }
//
//    private func send() {
//        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !t.isEmpty else { return }
//        vm.sendChat(userInput: t)
//        draft = ""
//    }
//
//    // MARK: Toolbars
//
//    private var connectButton: some View {
//        Group {
//            switch vm.connectionState {
//            case .connected: Button { vm.disconnect() } label: { Label("断开", systemImage: "bolt.slash.fill") }
//            case .connecting: ProgressView().controlSize(.small)
//            case .disconnected: Button { vm.connect() } label: { Label("连接", systemImage: "bolt.fill") }
//            }
//        }
//    }
//    private var timestampMenu: some View {
//        Menu {
//            ForEach(TimestampStyle.allCases, id: \.rawValue) { s in
//                Button { tsStyleRaw = s.rawValue } label: { tsStyle == s ? Label(s.title, systemImage: "checkmark") : Label(s.title, systemImage: "x.square.fill") }
//            }
//        } label: { Image(systemName: "clock") }
//    }
//    private var notifyToggle: some View {
//        Toggle(isOn: $vm.mentionNotificationEnabled) { Image(systemName: "bell") }.toggleStyle(.switch)
//    }
//    private var channelMenu: some View {
//        Menu {
//            Section("当前频道") { Text(vm.currentChannel.displayName) }
//            Section("快速切换") {
//                ForEach(vm.channels) { ch in
//                    Button { vm.switchChannel(to: ch) } label: { Text(ch.displayName) }
//                }
//            }
//            Section("新建") {
//                Button("加入/创建公开频道…") {
//                    prompt("输入频道名") { name in
//                        guard let name, !name.isEmpty else { return }
//                        vm.switchChannel(to: Channel(name: name, kind: .publicRoom, displayName: "#\(name)"))
//                    }
//                }
//                Button("开始私聊…") {
//                    prompt("输入对方昵称") { peer in
//                        guard let peer, !peer.isEmpty else { return }
//                        vm.startDirectMessage(with: peer)
//                    }
//                }
//            }
//        } label: { Image(systemName: "bubble.left.and.bubble.right") }
//    }
//
//    // MARK: Pickers
//
//    private func handlePhotoPicked(_ item: PhotosPickerItem) async {
//        do {
//            guard let data = try await item.loadTransferable(type: Data.self) else { return }
//            let ut = item.supportedContentTypes.first
//            let ext = ut?.preferredFilenameExtension ?? "bin"
//            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
//            try data.write(to: tmp)
//            let meta = try await AttachmentService.shared.upload(url: tmp, fileName: nil)
//            vm.sendAttachment(meta: meta)
//        } catch { print("photo pick/upload error:", error) }
//    }
//    private func handleFilePicked(url: URL) async {
//        do {
//            let meta = try await AttachmentService.shared.upload(url: url, fileName: url.lastPathComponent)
//            vm.sendAttachment(meta: meta)
//        } catch { print("file upload error:", error) }
//    }
//
//    // 简易 prompt
//    private func prompt(_ title: String, handler: @escaping (String?) -> Void) {
//        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
//        alert.addTextField()
//        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in handler(nil) })
//        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in handler(alert.textFields?.first?.text) })
//        UIApplication.shared.firstKeyWindow?.rootViewController?.present(alert, animated: true)
//    }
//}

extension UIApplication {
    var firstKeyWindow: UIWindow? { connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow } }
}
