//
//  ExplorerView.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//  🧭 Explorer - 探索频道和用户
//

import SwiftUI

struct ExplorerView: View {
    var client: HackChatClient
    
    @State private var searchText = ""
    @State private var selectedCategory: ExploreCategory = .channels
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ModernTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ModernTheme.spacing5) {
                        // 搜索框
                        ModernSearchBar(text: $searchText)
                            .padding(.horizontal, ModernTheme.spacing4)
                        
                        // 分类选择器
                        CategoryPicker(selectedCategory: $selectedCategory)
                            .padding(.horizontal, ModernTheme.spacing4)
                        
                        // 内容区域
                        switch selectedCategory {
                        case .channels:
                            PublicChannelsGrid(client: client, searchText: searchText)
                        case .trending:
                            TrendingSection(client: client)
                        case .users:
                            UsersGrid(client: client, searchText: searchText)
                        }
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.top, ModernTheme.spacing3)
                }
            }
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 📂 探索分类

enum ExploreCategory: String, CaseIterable {
    case channels = "频道"
    case trending = "热门"
    case users = "用户"
    
    var icon: String {
        switch self {
        case .channels: return "number.square"
        case .trending: return "flame.fill"
        case .users: return "person.3.fill"
        }
    }
}

// MARK: - 🎯 分类选择器

struct CategoryPicker: View {
    @Binding var selectedCategory: ExploreCategory
    
    var body: some View {
        HStack(spacing: ModernTheme.spacing2) {
            ForEach(ExploreCategory.allCases, id: \.self) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategory == category
                ) {
                    withAnimation(ModernTheme.standardSpring) {
                        selectedCategory = category
                    }
                    HapticManager.selection()
                }
            }
        }
        .padding(ModernTheme.spacing1)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
        .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct CategoryButton: View {
    let category: ExploreCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernTheme.spacing2) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(ModernTheme.subheadline)
            }
            .foregroundColor(isSelected ? .white : ModernTheme.secondaryText)
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.vertical, ModernTheme.spacing2)
            .background(
                isSelected ? ModernTheme.accent : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 📺 公开频道网格

struct PublicChannelsGrid: View {
    var client: HackChatClient
    var searchText: String
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private var channels: [String] {
        let allChannels = Array(client.state.messagesByChannel.keys)
        if searchText.isEmpty {
            return allChannels
        }
        return allChannels.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: ModernTheme.spacing3) {
            ForEach(channels, id: \.self) { channel in
                ChannelDiscoverCard(channelName: channel) {
                    client.sendText("/join \(channel)")
                    HapticManager.impact(style: .light)
                }
            }
        }
        .padding(.horizontal, ModernTheme.spacing4)
    }
}

// MARK: - 🔥 热门区域

struct TrendingSection: View {
    var client: HackChatClient
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            SectionHeader(
                icon: "flame.fill",
                title: "热门话题",
                iconColor: ModernTheme.warning
            )
            .padding(.horizontal, ModernTheme.spacing4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernTheme.spacing3) {
                    ForEach(0..<5) { index in
                        TrendingTopicCard(topic: "话题 \(index + 1)", count: Int.random(in: 10...100))
                    }
                }
                .padding(.horizontal, ModernTheme.spacing4)
            }
            
            SectionHeader(
                icon: "chart.line.uptrend.xyaxis",
                title: "活跃频道",
                iconColor: ModernTheme.success
            )
            .padding(.horizontal, ModernTheme.spacing4)
            .padding(.top, ModernTheme.spacing4)
            
            VStack(spacing: ModernTheme.spacing2) {
                ForEach(Array(client.state.messagesByChannel.keys.prefix(5)), id: \.self) { channel in
                    ActiveChannelRow(channelName: channel) {
                        client.sendText("/join \(channel)")
                    }
                    .padding(.horizontal, ModernTheme.spacing4)
                }
            }
        }
    }
}

// MARK: - 👥 用户网格

struct UsersGrid: View {
    var client: HackChatClient
    var searchText: String
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private var users: [String] {
        let allUsers = Array(client.state.onlineByRoom[client.currentChannel] ?? [])
        if searchText.isEmpty {
            return allUsers
        }
        return allUsers.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: ModernTheme.spacing3) {
            ForEach(users, id: \.self) { user in
                UserDiscoverCard(username: user)
            }
        }
        .padding(.horizontal, ModernTheme.spacing4)
    }
}

// MARK: - 🎴 频道发现卡片

struct ChannelDiscoverCard: View {
    let channelName: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ModernTheme.accent.opacity(0.2),
                                    ModernTheme.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                    
                    Image(systemName: "number")
                        .font(.system(size: 32))
                        .foregroundColor(ModernTheme.accent)
                }
                
                VStack(alignment: .leading, spacing: ModernTheme.spacing1) {
                    Text(channelName)
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(ModernTheme.primaryText)
                        .lineLimit(1)
                    
                    Text("加入频道")
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                }
            }
            .padding(ModernTheme.spacing3)
            .background(ModernTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
            .shadow(color: ModernTheme.cardShadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 🔥 热门话题卡片

struct TrendingTopicCard: View {
    let topic: String
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing2) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(ModernTheme.warning)
                Spacer()
                Text("\(count)")
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.secondaryText)
            }
            
            Text(topic)
                .font(ModernTheme.bodyBold)
                .foregroundColor(ModernTheme.primaryText)
        }
        .padding(ModernTheme.spacing4)
        .frame(width: 160)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
        .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

// MARK: - 📊 活跃频道行

struct ActiveChannelRow: View {
    let channelName: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ModernTheme.spacing3) {
                Circle()
                    .fill(ModernTheme.success.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(ModernTheme.success)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(channelName)
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(ModernTheme.primaryText)
                    
                    Text("活跃中")
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(ModernTheme.tertiaryText)
            }
            .padding(ModernTheme.spacing3)
            .background(ModernTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
            .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 👤 用户发现卡片

struct UserDiscoverCard: View {
    let username: String
    
    private var userColor: Color {
        let colors: [Color] = [
            ModernTheme.accent,
            ModernTheme.secondaryAccent,
            ModernTheme.success,
            ModernTheme.warning,
            Color(hex: "9B8CD1")
        ]
        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        VStack(spacing: ModernTheme.spacing2) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            userColor.opacity(0.3),
                            userColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Text(username.prefix(1).uppercased())
                        .font(ModernTheme.title3)
                        .foregroundColor(userColor)
                )
            
            Text(username)
                .font(ModernTheme.caption)
                .foregroundColor(ModernTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ModernTheme.spacing3)
        .background(ModernTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous))
        .shadow(color: ModernTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

