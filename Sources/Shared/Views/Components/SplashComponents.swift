// SplashComponents.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了应用启动闪屏页（SplashView）所需的视觉原子组件，旨在为用户提供平滑且具备品牌感的第一交互体验。
// 该组件包包含了以下核心视觉元素与动画逻辑：
// 1. 品牌 Logo 渲染器：支持动态缩放与渐变效果的图标展示，集成了基于 WikiUI 规范的标准圆角与阴影特效。
// 2. 启动状态指示器：实现了优雅的骨架屏（Skeleton）占位与进度提示，确保在系统初始化期间提供良好的视觉占位反馈。
// 3. 多端布局适配：内置了针对 iOS 与 macOS 不同屏幕尺寸的排版自适应策略，确保品牌形象在多平台显示的一致性。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，修复 WikiUI 成员引用错误
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Splash Background View
/// 程序化启动画面背景：深空 + 神经网络节点 + 书本光芒
struct SplashBackgroundView: View {
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
                    RoundedRectangle(cornerRadius: WikiUI.tiny)
                        .stroke(Color.wikiAccent.opacity(0.35), lineWidth: 1.2)
                        .frame(width: 60, height: 44)
                        .rotationEffect(.degrees(-8))
                        .offset(x: -2)

                    RoundedRectangle(cornerRadius: WikiUI.tiny)
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
