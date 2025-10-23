//
//  SettingsView.swift
//  HChat
//
//  Created on 2025-10-23.
//  ⚙️ 设置视图
//

import SwiftUI

struct SettingsView: View {
    let client: HackChatClient
    
    var body: some View {
        NavigationStack {
            List {
                // 个人信息
                Section {
                    HStack {
                        Circle()
                            .fill(colorForNickname(client.myNick))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(client.myNick.prefix(1).uppercased())
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.myNick)
                                .font(.title3.bold())
                            
                            Text("点击修改昵称")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 12)
                    }
                    .padding(.vertical, 8)
                }
                
                // 通用设置
                Section("通用") {
                    NavigationLink {
                        Text("通知设置")
                    } label: {
                        Label("通知设置", systemImage: "bell.fill")
                    }
                    
                    NavigationLink {
                        Text("隐私设置")
                    } label: {
                        Label("隐私", systemImage: "lock.fill")
                    }
                    
                    NavigationLink {
                        Text("聊天设置")
                    } label: {
                        Label("聊天", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }
                
                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/novolei/HChat")!) {
                        Label("GitHub", systemImage: "star.fill")
                    }
                }
                
                // 退出登录（占位符）
                Section {
                    Button(role: .destructive) {
                        // TODO: 实现退出登录
                    } label: {
                        Text("退出登录")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("我")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

