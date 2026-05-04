// MedalComponents.swift
//
// 作者: Wang Chong
// 功能说明: 奖章卡片视图
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 奖章卡片视图
struct MedalCard: View {
    let medal: MedalService.Medal
    let isEarned: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isEarned ? Color(hex: medal.colorHex).opacity(0.15) : Color.wikiBorder.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: medal.icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(isEarned ? Color(hex: medal.colorHex) : .wikiSecondary.opacity(0.5))
                
                if !isEarned {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .padding(4)
                        .background(Circle().fill(.ultraThinMaterial))
                        .offset(x: 25, y: 25)
                }
            }
            
            VStack(spacing: 4) {
                Text(Localized.tr(medal.titleKey))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isEarned ? .wikiText : .wikiSecondary)
                
                Text(Localized.tr(medal.descKey))
                    .font(.system(size: 10))
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isEarned ? Color(hex: medal.colorHex).opacity(0.3) : Color.wikiBorder.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: isEarned ? Color(hex: medal.colorHex).opacity(0.1) : .clear, radius: 10, y: 4)
        .grayscale(isEarned ? 0 : 1)
        .opacity(isEarned ? 1 : 0.7)
    }
}

/// 奖章奖励弹窗
struct MedalRewardPopup: View {
    let medal: MedalService.Medal
    let onDismiss: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: 24) {
                // 顶部闪烁装饰
                ZStack {
                    Circle()
                        .fill(Color(hex: medal.colorHex).opacity(0.2))
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                    
                    Image(systemName: medal.icon)
                        .font(.system(size: 80, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: medal.colorHex), Color(hex: medal.colorHex).opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(hex: medal.colorHex).opacity(0.5), radius: 20, y: 10)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                }
                .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text(Localized.tr("medal.congrats"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.wikiAccent)
                        .kerning(2)
                    
                    Text(Localized.tr(medal.titleKey))
                        .font(.title.bold())
                        .foregroundStyle(.wikiText)
                    
                    Text(Localized.tr(medal.descKey))
                        .font(.body)
                        .foregroundStyle(.wikiSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button(action: onDismiss) {
                    Text(L10n.Common.tr("awesome"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 50)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: medal.colorHex), Color(hex: medal.colorHex).opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                        )
                        .shadow(color: Color(hex: medal.colorHex).opacity(0.3), radius: 10, y: 5)
                }
                .padding(.bottom, 40)
                .scaleEffect(isAnimating ? 1 : 0.9)
            }
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.wikiCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
            )
            .padding(24)
            .scaleEffect(isAnimating ? 1 : 0.5)
            .opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                isAnimating = true
            }
        }
    }
}
