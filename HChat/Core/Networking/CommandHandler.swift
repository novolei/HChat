//
//  CommandHandler.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/21.
//  命令处理逻辑
//

import Foundation

@MainActor
final class CommandHandler {
    private weak var state: ChatState?
    private let sendMessage: ([String: Any]) -> Void
    
    init(state: ChatState, sendMessage: @escaping ([String: Any]) -> Void) {
        self.state = state
        self.sendMessage = sendMessage
    }
    
    /// 处理客户端命令
    func handle(_ cmd: ClientCommand) {
        guard let state = state else { return }
        
        switch cmd {
        case .join(let room):
            handleJoin(room, state: state)
            
        case .nick(let name):
            handleNick(name, state: state)
            
        case .dm(let to, let text):
            handleDirectMessage(to: to, text: text, state: state)
            
        case .me(let action):
            handleMeAction(action, state: state)
            
        case .clear:
            state.clearCurrentChannelMessages()
            
        case .help:
            state.systemMessage("支持命令：/join /nick /me /clear /help")
            
        case .unknown(let raw):
            state.systemMessage("未知命令：\(raw)")
        }
    }
    
    // MARK: - 私有处理方法
    
    private func handleJoin(_ room: String, state: ChatState) {
        state.joinChannel(room)
        state.systemMessage("已加入 #\(room)")
    }
    
    private func handleNick(_ name: String, state: ChatState) {
        let isFirstTimeSetup = state.myNick == "iOSUser" || state.myNick.hasPrefix("iOSUser")
        state.myNick = name
        
        // 发送 nick 命令到服务器，同步昵称
        sendMessage(["type": "nick", "nick": name])
        DebugLogger.log("👤 发送昵称变更到服务器: \(name)", level: .websocket)
        
        // 检查是否设置了群口令
        if let pass = CommandParser.extractPassphrase(fromNick: name) {
            state.passphraseForEndToEndEncryption = pass
            state.systemMessage("E2EE 群口令已更新")
        } else if isFirstTimeSetup {
            // 首次设置昵称时显示进入频道的提示
            state.systemMessage("\(name) 进入 #\(state.currentChannel)")
        }
    }
    
    private func handleDirectMessage(to: String, text: String, state: ChatState) {
        let id = UUID().uuidString
        state.markMessageAsSent(id: id)
        
        // 归入一个 "pm/\(to)" 的本地会话
        let ch = "pm/\(to)"
        state.appendMessage(ChatMessage(id: id, channel: ch, sender: state.myNick, text: text, isLocalEcho: true))
        sendMessage(["type": "dm", "id": id, "to": to, "text": text])
    }
    
    private func handleMeAction(_ action: String, state: ChatState) {
        let m = ChatMessage(channel: state.currentChannel, sender: state.myNick, text: "/me \(action)")
        state.appendMessage(m)
        sendMessage(["channel": state.currentChannel, "nick": state.myNick, "text": "/me \(action)"])
    }
}

