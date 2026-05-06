// Shimmer.swift
//
// 作者: Wang Chong
// 功能说明: 现代感十足的骨架屏微光修饰符
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

/// 现代感十足的骨架屏微光修饰符
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: phase - 0.2),
                            .init(color: .white.opacity(0.3), location: phase),
                            .init(color: .clear, location: phase + 0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .scaleEffect(3) // 确保渐变覆盖足够广
                    .rotationEffect(.degrees(30))
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    /// 为任何视图添加微光扫过效果
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

/// 骨架屏占位块
struct SkeletonBox: View {
    var width: CGFloat? = nil
    var height: CGFloat = 20
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.wikiBorder.opacity(0.4))
            .frame(width: width, height: height)
            .shimmer()
    }
}
