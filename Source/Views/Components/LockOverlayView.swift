import SwiftUI

/// 锁定界面 (Security & Design 视角：提供高级感与安全感)
struct LockOverlayView: View {
    @EnvironmentObject var store: KMStore
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 1. 深度毛玻璃背景
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay {
                    Color.wikiBackground.opacity(0.4)
                }
            
            VStack(spacing: 40) {
                // 2. 动态锁图标
                ZStack {
                    // 外围光晕
                    Circle()
                        .fill(Color.wikiAccent.opacity(0.15))
                        .frame(width: 160, height: 160)
                        .blur(radius: 30)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                    
                    // 核心图标
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.wikiAccent, .wikiAccent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .wikiAccent.opacity(0.4), radius: 20, y: 10)
                            .symbolEffect(.bounce, value: isAnimating)
                    }
                }
                
                // 3. 文字提示
                VStack(spacing: 8) {
                    Text(Localized.tr("security.vaultLocked"))
                        .font(.title2.bold())
                        .foregroundStyle(.wikiText)
                    
                    Text(Localized.tr("security.unlockHint"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // 4. 高级感解锁按钮
                Button(action: { store.securityService.unlock() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.title3)
                        Text(Localized.tr("security.unlock"))
                            .font(.headline)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(Color.wikiAccent)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: .wikiAccent.opacity(0.3), radius: 15, y: 8)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// Moved to WikiUI.swift
