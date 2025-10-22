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
    @State private var selectedCategory: ExploreCategory = .templates
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.twilightGradient
                    .ignoresSafeArea()
                LinearGradient(colors: [Color.black.opacity(0.25), Color.clear], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: ModernTheme.spacing7) {
                        heroSection
                        discoverySection
                        templatesSection
                        ritualsSection
                        recommendationsSection
                    }
                    .padding(.horizontal, ModernTheme.spacing5)
                    .padding(.bottom, ModernTheme.spacing7)
                }
            }
            .navigationTitle("发现灵感")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            Text("只属于你们的回忆仪式")
                .font(ModernTheme.largeTitle)
                .foregroundColor(.white)
            
            Text("探索情侣主题包、仪式模版和季节限定灵感，让记忆流更有温度。")
                .font(ModernTheme.subheadline)
                .foregroundColor(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            
            searchBar
        }
        .padding(ModernTheme.spacing6)
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.extraLargeRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernTheme.extraLargeRadius, style: .continuous)
                        .stroke(LinearGradient(colors: [ModernTheme.accent.opacity(0.6), ModernTheme.secondaryAccent.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                )
        )
        .shadow(color: ModernTheme.cardShadow, radius: 12, x: 0, y: 6)
        .padding(.top, ModernTheme.spacing6)
    }
    
    private var searchBar: some View {
        HStack(spacing: ModernTheme.spacing3) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.8))
            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("搜索模板、主题或情绪仪式")
                        .foregroundColor(.white.opacity(0.55))
                }
                TextField("", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, ModernTheme.spacing4)
        .padding(.vertical, ModernTheme.spacing3)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
    }
    
    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
            Text("探索分类")
                .font(ModernTheme.title3)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernTheme.spacing3) {
                    ForEach(ExploreCategory.allCases, id: \.self) { category in
                        Button {
                            withAnimation(ModernTheme.standardSpring) {
                                selectedCategory = category
                            }
                        } label: {
                            HStack(spacing: ModernTheme.spacing2) {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                                    .fontWeight(.medium)
                            }
                            .font(ModernTheme.caption)
                            .foregroundColor(selectedCategory == category ? .white : Color.white.opacity(0.7))
                            .padding(.horizontal, ModernTheme.spacing4)
                            .padding(.vertical, ModernTheme.spacing2)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            sectionHeader(title: "精选模板", subtitle: "让记忆流更有仪式感")
            
            let templates = MemoryMoment.AccentStyle.allCases
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernTheme.spacing4) {
                    ForEach(templates, id: \.self) { style in
                        TemplateCard(style: style) {
                            // TODO: 应用模板
                        }
                    }
                }
            }
        }
        .modernCard(padding: ModernTheme.spacing5, backgroundColor: Color.white.opacity(0.15), shadowRadius: 8, blurRadius: 20, borderGradient: ModernTheme.cardGradient)
    }
    
    private var ritualsSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            sectionHeader(title: "仪式灵感", subtitle: "创造属于你们的小习惯")
            VStack(spacing: ModernTheme.spacing3) {
                RitualActionButton(title: "夜间回顾", subtitle: "睡前 10 分钟互道感谢", icon: "moon.stars", gradient: ModernTheme.twilightGradient) {}
                RitualActionButton(title: "周末心情胶囊", subtitle: "每周日写下 3 件开心小事", icon: "capsule.fill", gradient: ModernTheme.dawnGradient) {}
                RitualActionButton(title: "旅行主题包", subtitle: "加入地理标签与旅途音乐", icon: "airplane", gradient: ModernTheme.duskGradient) {}
            }
        }
        .modernCard(padding: ModernTheme.spacing5, backgroundColor: Color.white.opacity(0.12), shadowRadius: 8, blurRadius: 16, borderGradient: ModernTheme.cardGradient)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            sectionHeader(title: "热门收藏", subtitle: "其他情侣最近在使用")
            VStack(spacing: ModernTheme.spacing3) {
                ForEach(Recommendation.sampleData) { item in
                    RecommendationRow(recommendation: item) {
                        // TODO: 应用收藏
                    }
                }
            }
        }
        .modernCard(padding: ModernTheme.spacing5, backgroundColor: Color.white.opacity(0.1), shadowRadius: 8, blurRadius: 16, borderGradient: ModernTheme.cardGradient)
    }
    
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ModernTheme.title3)
                .foregroundColor(.white)
            Text(subtitle)
                .font(ModernTheme.caption)
                .foregroundColor(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Supporting Views & Data

enum ExploreCategory: String, CaseIterable {
    case templates = "记忆模板"
    case rituals = "仪式灵感"
    case collaborations = "联名主题"
    
    var icon: String {
        switch self {
        case .templates: return "sparkles.rectangle"
        case .rituals: return "hands.sparkles"
        case .collaborations: return "gift.fill"
        }
    }
}

struct TemplateCard: View {
    let style: MemoryMoment.AccentStyle
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous)
                    .fill(style.gradient)
                    .frame(width: 180, height: 120)
                    .overlay(
                        Image(systemName: "sparkles")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 38, weight: .semibold))
                    )
                Text(title(for: style))
                    .font(ModernTheme.bodyBold)
                    .foregroundColor(.white)
                Text(description(for: style))
                    .font(ModernTheme.caption)
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(2)
            }
            .padding(ModernTheme.spacing4)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func title(for style: MemoryMoment.AccentStyle) -> String {
        switch style {
        case .dawn: return "晨曦柔光"
        case .dusk: return "黄昏漫染"
        case .twilight: return "星夜低语"
        case .meadow: return "暖绿萤光"
        }
    }
    
    private func description(for style: MemoryMoment.AccentStyle) -> String {
        switch style {
        case .dawn: return "适合初恋期的暖意渐层";
        case .dusk: return "旅行记忆常用的落日滤镜";
        case .twilight: return "夜晚语音、心事沉浸";
        case .meadow: return "自然系情侣的氧气感";
        }
    }
}

struct Recommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let gradient: LinearGradient
    
    static let sampleData: [Recommendation] = [
        Recommendation(title: "恋爱 100 天倒数", description: "使用 twilight 模板 + 纪念日提醒", icon: "calendar", gradient: ModernTheme.twilightGradient),
        Recommendation(title: "第一支情侣歌", description: "搭配 dawn 主题导出动画", icon: "music.note", gradient: ModernTheme.dawnGradient),
        Recommendation(title: "旅行故事板", description: "整理巴厘岛旅程，配合草地主题", icon: "airplane", gradient: ModernTheme.meadowGradient)
    ]
}

struct RecommendationRow: View {
    let recommendation: Recommendation
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernTheme.spacing4) {
                RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous)
                    .fill(recommendation.gradient)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: recommendation.icon)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(.white)
                    Text(recommendation.description)
                        .font(ModernTheme.caption)
                        .foregroundColor(Color.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(ModernTheme.spacing4)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

