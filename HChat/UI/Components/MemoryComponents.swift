//
//  MemoryComponents.swift
//  HChat
//
//  Created by AI Assistant on 2025/10/22.
//  ✨ 记忆流核心组件（MemoryMomentCard、EmotionChip、RitualActionButton 等）
//

import SwiftUI

struct MemoryMomentCard: View {
    let moment: MemoryMoment
    var onTap: (() -> Void)?
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: ModernTheme.spacing3) {
                HStack(spacing: ModernTheme.spacing3) {
                    ZStack {
                        Circle()
                            .fill(moment.accentGradient)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: moment.emotion.icon)
                                    .foregroundColor(.white)
                                    .font(.system(size: 22, weight: .semibold))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(moment.title)
                            .font(ModernTheme.title3)
                            .foregroundColor(ModernTheme.primaryText)
                        Text(moment.timestamp, style: .date)
                            .font(ModernTheme.caption)
                            .foregroundColor(ModernTheme.secondaryText)
                    }
                    Spacer(minLength: 16)
                    EmotionChip(emotion: moment.emotion)
                }
                
                Text(moment.detail)
                    .font(ModernTheme.body)
                    .foregroundColor(ModernTheme.secondaryText)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: ModernTheme.spacing3) {
                    Label(moment.contentType.displayName, systemImage: moment.contentType.icon)
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                        .padding(.horizontal, ModernTheme.spacing3)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ModernTheme.capsuleBackground)
                        )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(ModernTheme.secondaryText)
                }
            }
            .padding(.vertical, ModernTheme.spacing4)
            .padding(.horizontal, ModernTheme.spacing4)
            .modernCard(borderGradient: moment.accentGradient)
        }
        .buttonStyle(.plain)
    }
}

struct FavoriteContactRow: View {
    let contact: FavoriteContact
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernTheme.spacing3) {
                Circle()
                    .fill(LinearGradient(colors: [ModernTheme.accent.opacity(0.7), ModernTheme.secondaryAccent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: contact.avatar)
                            .foregroundColor(.white)
                            .font(.system(size: 26, weight: .semibold))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(ModernTheme.primaryText)
                    Text(contact.status)
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(ModernTheme.tertiaryText)
            }
            .padding(ModernTheme.spacing4)
            .modernCard()
        }
        .buttonStyle(.plain)
    }
}

struct ChatPreviewRow: View {
    let preview: ChatPreview
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernTheme.spacing3) {
                RoundedRectangle(cornerRadius: ModernTheme.mediumRadius, style: .continuous)
                    .fill(LinearGradient(colors: [ModernTheme.secondaryAccent.opacity(0.6), ModernTheme.accent.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.white)
                            Text("#")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.caption)
                        }
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.channel)
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(ModernTheme.primaryText)
                    Text(preview.lastMessage)
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Text(preview.timestamp, style: .time)
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.tertiaryText)
            }
            .padding(ModernTheme.spacing4)
            .modernCard()
        }
        .buttonStyle(.plain)
    }
}

struct EmotionChip: View {
    let emotion: EmotionTag
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: emotion.icon)
            Text(emotion.displayName)
                .fontWeight(.medium)
        }
        .font(ModernTheme.caption)
        .foregroundColor(.white)
        .padding(.horizontal, ModernTheme.spacing3)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(emotion.color)
        )
    }
}

struct RitualActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernTheme.spacing4) {
                Circle()
                    .fill(gradient)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ModernTheme.bodyBold)
                        .foregroundColor(ModernTheme.primaryText)
                    Text(subtitle)
                        .font(ModernTheme.caption)
                        .foregroundColor(ModernTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(ModernTheme.secondaryText)
            }
            .padding(ModernTheme.spacing4)
            .modernCard(borderGradient: gradient)
        }
        .buttonStyle(.plain)
    }
}

struct QuickCaptureButton: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: ModernTheme.spacing2) {
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: ModernTheme.cardShadow, radius: 12, x: 0, y: 6)
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 22, weight: .semibold))
                }
                Text(title)
                    .font(ModernTheme.caption)
                    .foregroundColor(ModernTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}
