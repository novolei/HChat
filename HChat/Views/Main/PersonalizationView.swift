//
//  PersonalizationView.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/22.
//  ✨ 私感空间：主题、仪式、AI 摘要
//

import SwiftUI

struct PersonalizationView: View {
    var client: HackChatClient
    
    @State private var selectedTheme: MemoryMoment.AccentStyle = .dawn
    @State private var autoDestroy = false
    @State private var unlockEmotion: EmotionTag = .joy
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: ModernTheme.spacing6) {
                        themeSection
                        ritualSection
                        summarySection
                    }
                    .padding(.horizontal, ModernTheme.spacing5)
                    .padding(.bottom, ModernTheme.spacing7)
                }
            }
            .navigationTitle("私感空间")
        }
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            Text("主题渐层")
                .font(ModernTheme.title3)
                .foregroundColor(ModernTheme.primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ModernTheme.spacing4) {
                ForEach(MemoryMoment.AccentStyle.allCases) { style in
                    Button {
                        withAnimation(ModernTheme.standardAnimation) {
                            selectedTheme = style
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous)
                            .fill(style.gradient)
                            .frame(height: 120)
                            .overlay(
                                VStack(spacing: ModernTheme.spacing2) {
                                    Text(style.rawValue.capitalized)
                                        .font(ModernTheme.bodyBold)
                                        .foregroundColor(.white)
                                    Image(systemName: selectedTheme == style ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.white)
                                }
                            )
                            .shadow(color: ModernTheme.cardShadow, radius: 10, x: 0, y: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous)
                                    .stroke(Color.white.opacity(selectedTheme == style ? 0.8 : 0.3), lineWidth: selectedTheme == style ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .modernCard(padding: ModernTheme.spacing5)
    }
    
    private var ritualSection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            Text("隐私仪式")
                .font(ModernTheme.title3)
                .foregroundColor(ModernTheme.primaryText)
            
            Toggle(isOn: $autoDestroy) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自动销毁")
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(ModernTheme.primaryText)
                    Text("开启后，超过时限的记忆将自动清除，仅双方设备同步执行")
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: ModernTheme.accent))
            
            Divider().background(ModernTheme.separator)
            
            VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                Text("情绪解锁")
                    .font(ModernTheme.bodyBold)
                    .foregroundColor(ModernTheme.primaryText)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ModernTheme.spacing3) {
                        ForEach(EmotionTag.allCases) { emotion in
                            Button {
                                unlockEmotion = emotion
                            } label: {
                                HStack(spacing: ModernTheme.spacing2) {
                                    Image(systemName: emotion.icon)
                                    Text(emotion.displayName)
                                }
                                .font(ModernTheme.caption)
                                .foregroundColor(unlockEmotion == emotion ? .white : ModernTheme.secondaryText)
                                .padding(.horizontal, ModernTheme.spacing4)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(unlockEmotion == emotion ? ModernTheme.accent : ModernTheme.capsuleBackground)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("在 \(unlockEmotion.displayName) 情绪下可解锁所有回忆")
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.secondaryText)
            }
        }
        .modernCard(padding: ModernTheme.spacing5)
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ModernTheme.spacing4) {
            Text("AI 温度摘要")
                .font(ModernTheme.title3)
                .foregroundColor(ModernTheme.primaryText)
            
            VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                Text("情感曲线")
                    .font(ModernTheme.bodyBold)
                GradientLineChart()
                    .frame(height: 140)
                
                Text("今日回顾卡片")
                    .font(ModernTheme.bodyBold)
                VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                    Text("两人在语音里互相鼓励对方，情绪趋于稳定；存在两个待完成的小愿望，推荐设置提醒。")
                        .font(ModernTheme.body)
                        .foregroundColor(ModernTheme.secondaryText)
                    Button {
                        // 导出动画
                    } label: {
                        Label("导出动画", systemImage: "sparkles")
                            .font(ModernTheme.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ModernTheme.accent)
                }
            }
        }
        .modernCard(padding: ModernTheme.spacing5)
    }
}

private struct GradientLineChart: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let path = Path { path in
                path.move(to: CGPoint(x: 0, y: height * 0.7))
                path.addCurve(to: CGPoint(x: width * 0.3, y: height * 0.4), control1: CGPoint(x: width * 0.1, y: height * 0.65), control2: CGPoint(x: width * 0.2, y: height * 0.45))
                path.addCurve(to: CGPoint(x: width * 0.6, y: height * 0.2), control1: CGPoint(x: width * 0.4, y: height * 0.35), control2: CGPoint(x: width * 0.5, y: height * 0.25))
                path.addCurve(to: CGPoint(x: width * 0.9, y: height * 0.35), control1: CGPoint(x: width * 0.7, y: height * 0.15), control2: CGPoint(x: width * 0.8, y: height * 0.25))
                path.addCurve(to: CGPoint(x: width, y: height * 0.1), control1: CGPoint(x: width * 0.95, y: height * 0.45), control2: CGPoint(x: width * 0.98, y: height * 0.2))
            }
            
            path
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .fill(LinearGradient(colors: [ModernTheme.accent, ModernTheme.secondaryAccent], startPoint: .leading, endPoint: .trailing))
                .shadow(color: ModernTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .background(
            RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous)
                .fill(ModernTheme.capsuleBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: ModernTheme.largeRadius, style: .continuous))
    }
}
