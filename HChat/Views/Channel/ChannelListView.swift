//
//  ChannelListView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import SwiftUI

struct ChannelListView: View {
    let channels: [Channel]
    let current: String
    var onSelect: (String) -> Void
    var onCreate: () -> Void
    var onStartDM: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(channels) { ch in
                    Button {
                        onSelect(ch.name)
                    } label: {
                        HStack {
                            Image(systemName: ch.name == current ? "number.square.fill" : "number.square")
                            Text("#\(ch.name)")
                                .fontWeight(ch.name == current ? .semibold : .regular)
                            Spacer()
                            if ch.unreadCount > 0 {
                                Text("\(ch.unreadCount)")
                                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red.opacity(0.85)))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            } header: {
                Text("频道")
            }

            Section {
                Button {
                    onCreate()
                } label: {
                    Label("新建频道", systemImage: "plus.circle")
                }
                Button {
                    onStartDM()
                } label: {
                    Label("开始私聊…", systemImage: "person.crop.circle.badge.plus")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("频道")
    }
}
