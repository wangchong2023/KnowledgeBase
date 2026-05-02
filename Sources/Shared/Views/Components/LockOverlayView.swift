import SwiftUI

/// 锁定界面 (Security & Design 视角：提供高级感与安全感)
struct LockOverlayView: View {
    @EnvironmentObject var store: KMStore
    @State private var isAnimating = false
    
    private var unlockIcon: String {
        #if os(macOS)
        return "touchid"
        #else
        return "faceid"
        #endif
    }
    
    private var titleSize: CGFloat {
        #if os(macOS)
        return 36
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? 36 : 28
        #endif
    }

    var body: some View {
        ZStack {
            // 1. Immersive Deep Glass Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // Animated Background Glows
            ZStack {
                Circle()
                    .fill(Color.wikiAccent.opacity(0.12))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: isAnimating ? 150 : -150, y: isAnimating ? -100 : 100)
                
                Circle()
                    .fill(Color.purple.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: isAnimating ? -180 : 180, y: isAnimating ? 80 : -80)
            }
            .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 40) {
                Spacer()
                
                // 2. The Vault Icon Container
                ZStack {
                    // Rotating decorative rings
                    Circle()
                        .stroke(
                            LinearGradient(colors: [Color.wikiAccent.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isAnimating)
                    
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.clear, Color.wikiAccent.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(isAnimating ? -360 : 0))
                        .animation(.linear(duration: 25).repeatForever(autoreverses: false), value: isAnimating)

                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.wikiAccent, Color.wikiAccent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.wikiAccent.opacity(0.4), radius: 30, y: 15)
                            .symbolEffect(.bounce, options: .repeat(2), value: isAnimating)
                    }
                }
                
                // 3. Information & Copy
                VStack(spacing: 12) {
                    Text(Localized.tr("security.vaultLocked"))
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.wikiText)
                    
                    Text(Localized.tr("security.unlockHint"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                // 4. Elegant Unlock Button
                Button(action: { 
                    #if os(iOS)
                    HapticManager.shared.trigger(.selection)
                    #endif
                    store.securityService.unlock() 
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: unlockIcon)
                            .font(.title2)
                        
                        Text(Localized.tr("security.unlock"))
                            .font(.headline)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 18)
                    .background {
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.wikiAccent, Color.wikiAccent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Capsule()
                                .stroke(.white.opacity(0.4), lineWidth: 0.5)
                        }
                    }
                    .foregroundStyle(.white)
                    .shadow(color: Color.wikiAccent.opacity(0.5), radius: 25, y: 12)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, 60)
            }
            .padding(.horizontal)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Moved to WikiUI.swift
