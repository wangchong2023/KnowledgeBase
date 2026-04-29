import SwiftUI

// MARK: - SplashView
/// 启动画面：Karpathy 名言 + 程序化生成的书本+神经网络星空背景
struct SplashView: View {
    @State private var quoteOpacity: Double = 0
    @State private var authorOpacity: Double = 0
    @State private var logoOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var starTwinkle = false
    @State private var nodeGlow = false
    
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // MARK: 程序化背景
            SplashBackgroundView(starTwinkle: starTwinkle, nodeGlow: nodeGlow)
                .ignoresSafeArea()
            
            // 内容
            VStack(spacing: 0) {
                Spacer()
                
                // App Logo / 名称
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.wikiAccent, Color.wikiAccent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(logoOpacity)
                    
                    Text(L.tr("splash.appName"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(logoOpacity)
                }
                .padding(.bottom, 60)
                
                // 名言
                VStack(spacing: 16) {
                    Text(L.tr("splash.quote"))
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                        .opacity(quoteOpacity)
                    
                    // 闪光效果
                    Text(L.tr("splash.quote"))
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                        .offset(x: shimmerOffset)
                        .mask(
                            Text(L.tr("splash.quote"))
                                .font(.system(size: 17, weight: .medium, design: .serif))
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .padding(.horizontal, 40)
                        )
                        .opacity(quoteOpacity > 0.5 ? 0.4 : 0)
                    
                    // 署名
                    HStack(spacing: 0) {
                        Text("— ")
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Andrej Karpathy")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.wikiAccent.opacity(0.8), Color.wikiAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .opacity(authorOpacity)
                }
                
                Spacer()
                
                // 继续按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        onDismiss()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(L.tr("splash.enter"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.wikiAccent.opacity(0.25))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.wikiAccent.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .opacity(authorOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - 动画序列
    private func startAnimations() {
        // 背景动画启动
        starTwinkle = true
        nodeGlow = true
        
        // Logo 淡入
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1
        }
        
        // 名言淡入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 1.2)) {
                quoteOpacity = 1
            }
        }
        
        // 署名淡入
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.8)) {
                authorOpacity = 1
            }
        }
        
        // 闪光扫过
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 1.5)) {
                shimmerOffset = 200
            }
        }
        
        // 5 秒后自动进入（仅在用户未手动点击时）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                onDismiss()
            }
        }
    }
}

// MARK: - SplashBackgroundView
/// 程序化背景：深空 + 神经网络节点 + 书本光芒
private struct SplashBackgroundView: View {
    let starTwinkle: Bool
    let nodeGlow: Bool
    
    // 预生成的随机数据
    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (0.12, 0.08, 1.5, 0.0), (0.85, 0.05, 1.0, 0.3), (0.45, 0.12, 2.0, 0.6),
        (0.72, 0.18, 1.2, 0.2), (0.28, 0.22, 1.8, 0.8), (0.93, 0.25, 1.0, 0.1),
        (0.08, 0.30, 1.5, 0.5), (0.55, 0.08, 1.3, 0.7), (0.38, 0.28, 1.0, 0.4),
        (0.65, 0.32, 2.0, 0.9), (0.18, 0.42, 1.2, 0.15), (0.78, 0.38, 1.5, 0.55),
        (0.50, 0.45, 1.0, 0.35), (0.90, 0.48, 1.8, 0.75), (0.32, 0.52, 1.3, 0.25),
        (0.05, 0.55, 1.0, 0.65), (0.62, 0.58, 2.0, 0.45), (0.42, 0.35, 1.5, 0.85),
        (0.75, 0.55, 1.2, 0.05), (0.22, 0.62, 1.0, 0.95), (0.88, 0.62, 1.8, 0.38),
        (0.15, 0.68, 1.5, 0.58), (0.58, 0.42, 1.0, 0.18), (0.35, 0.72, 2.0, 0.78),
        (0.82, 0.72, 1.3, 0.28), (0.48, 0.68, 1.0, 0.48), (0.68, 0.48, 1.5, 0.68),
        (0.10, 0.78, 1.2, 0.88), (0.92, 0.82, 1.0, 0.08), (0.40, 0.82, 1.8, 0.42),
    ]
    
    // 神经网络节点位置
    private let networkNodes: [(x: CGFloat, y: CGFloat, size: CGFloat, isAccent: Bool)] = [
        (0.20, 0.15, 5, false), (0.40, 0.10, 6, true),  (0.60, 0.18, 5, false),
        (0.80, 0.12, 4, false), (0.15, 0.30, 4, false), (0.35, 0.28, 7, true),
        (0.55, 0.25, 5, false), (0.75, 0.30, 6, true),  (0.90, 0.22, 4, false),
        (0.25, 0.45, 5, false), (0.50, 0.40, 8, true),  (0.70, 0.42, 5, false),
        (0.10, 0.50, 4, false), (0.85, 0.48, 5, false), (0.30, 0.55, 6, true),
        (0.60, 0.52, 4, false), (0.80, 0.55, 5, false), (0.45, 0.60, 7, true),
    ]
    
    // 网络连接线
    private let connections: [(from: Int, to: Int)] = [
        (0, 1), (1, 2), (2, 3), (0, 4), (1, 5), (2, 6), (3, 7), (8, 7),
        (4, 5), (5, 6), (6, 7), (5, 10), (6, 10), (9, 10), (10, 11),
        (4, 9), (9, 14), (10, 15), (11, 16), (14, 17), (15, 17),
        (12, 9), (13, 16), (8, 5), (1, 6), (5, 10), (10, 17),
    ]
    
    var body: some View {
        ZStack {
            // 基底渐变：深靛蓝 → 深海军蓝 → 底部暖琥珀光
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.04, green: 0.04, blue: 0.12), location: 0.0),
                    .init(color: Color(red: 0.06, green: 0.08, blue: 0.22), location: 0.3),
                    .init(color: Color(red: 0.08, green: 0.10, blue: 0.28), location: 0.55),
                    .init(color: Color(red: 0.10, green: 0.12, blue: 0.30), location: 0.7),
                    .init(color: Color(red: 0.12, green: 0.10, blue: 0.22), location: 0.85),
                    .init(color: Color(red: 0.18, green: 0.12, blue: 0.15), location: 0.95),
                    .init(color: Color(red: 0.25, green: 0.15, blue: 0.10), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 星星层
            GeometryReader { geo in
                ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .position(x: geo.size.width * star.x, y: geo.size.height * star.y)
                        .opacity(starTwinkle ? 0.7 : 0.3)
                        .animation(
                            .easeInOut(duration: 1.5 + star.delay)
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                            value: starTwinkle
                        )
                }
            }
            
            // 神经网络连接线
            GeometryReader { geo in
                ForEach(Array(connections.enumerated()), id: \.offset) { _, conn in
                    let fromNode = networkNodes[conn.from]
                    let toNode = networkNodes[conn.to]
                    Path { path in
                        path.move(to: CGPoint(
                            x: geo.size.width * fromNode.x,
                            y: geo.size.height * fromNode.y
                        ))
                        path.addLine(to: CGPoint(
                            x: geo.size.width * toNode.x,
                            y: geo.size.height * toNode.y
                        ))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                fromNode.isAccent ? Color.wikiAccent.opacity(0.3) : Color.white.opacity(0.12),
                                toNode.isAccent ? Color.wikiAccent.opacity(0.3) : Color.white.opacity(0.12)
                            ],
                            startPoint: .init(x: fromNode.x, y: fromNode.y),
                            endPoint: .init(x: toNode.x, y: toNode.y)
                        ),
                        lineWidth: 0.8
                    )
                }
            }
            
            // 神经网络节点
            GeometryReader { geo in
                ForEach(Array(networkNodes.enumerated()), id: \.offset) { index, node in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    node.isAccent ? Color.wikiAccent.opacity(0.9) : Color.white.opacity(0.8),
                                    node.isAccent ? Color.wikiAccent.opacity(0.3) : Color.white.opacity(0.2),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: node.size * 2
                            )
                        )
                        .frame(width: node.size * 4, height: node.size * 4)
                        .position(x: geo.size.width * node.x, y: geo.size.height * node.y)
                        .scaleEffect(nodeGlow ? 1.0 : 0.5)
                        .opacity(nodeGlow ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 2.0 + Double(index) * 0.1)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08),
                            value: nodeGlow
                        )
                }
            }
            
            // 书本光芒 — 底部中央的暖光
            VStack {
                Spacer()
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.85, blue: 0.5).opacity(0.25),
                        Color(red: 0.9, green: 0.65, blue: 0.3).opacity(0.12),
                        Color(red: 0.7, green: 0.4, blue: 0.2).opacity(0.05),
                        .clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 250
                )
                .frame(height: 300)
                .offset(y: 80)
            }
            
            // 书本轮廓 — 极简线条
            VStack {
                Spacer()
                ZStack {
                    // 书本主体
                    RoundedRectangle(cornerRadius: WikiUI.inlineRadius)
                        .stroke(Color.wikiAccent.opacity(0.35), lineWidth: 1.2)
                        .frame(width: 60, height: 44)
                        .rotationEffect(.degrees(-8))
                        .offset(x: -2)
                    
                    RoundedRectangle(cornerRadius: WikiUI.inlineRadius)
                        .stroke(Color.wikiAccent.opacity(0.35), lineWidth: 1.2)
                        .frame(width: 60, height: 44)
                        .rotationEffect(.degrees(8))
                        .offset(x: 2)
                    
                    // 书脊
                    Capsule()
                        .fill(Color.wikiAccent.opacity(0.2))
                        .frame(width: 3, height: 44)
                    
                    // 从书中升起的光粒子
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color.wikiAccent.opacity(0.4))
                            .frame(width: 3, height: 3)
                            .offset(
                                x: CGFloat(i - 2) * 14,
                                y: nodeGlow ? -60 - CGFloat(i) * 15 : -20
                            )
                            .opacity(nodeGlow ? 0.6 : 0.1)
                            .animation(
                                .easeOut(duration: 3.0)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.4),
                                value: nodeGlow
                            )
                    }
                }
                .padding(.bottom, 180)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SplashView(onDismiss: {})
}
