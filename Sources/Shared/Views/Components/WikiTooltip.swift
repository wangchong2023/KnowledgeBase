// WikiTooltip.swift
//
// 作者: Wang Chong
// 功能说明: 引导提示组件，用于首次使用时的操作引导。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Wiki Tooltip
/// 引导提示组件，用于首次使用时的操作引导。
@MainActor
/// 操作引导提示组件
/// 负责在 UI 元素周围弹出气泡样式的提示信息，用于新手引导或新功能展示
struct WikiTooltip: View {
    let title: String
    let description: String
    let icon: String
    var arrowDirection: ArrowDirection = .top
    var accentColor: Color = .wikiAccent

    enum ArrowDirection {
        case top, bottom, left, right
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.wikiText)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: WikiUI.medium)
                .fill(Color.wikiCard)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        )
        .overlay(
            arrowView,
            alignment: arrowAlignment
        )
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
    }

    @ViewBuilder
    private var arrowView: some View {
        switch arrowDirection {
        case .top:
            VStack(spacing: 0) {
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 12, height: 8)
                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: -1)
                Spacer()
            }
        case .bottom:
            VStack(spacing: 0) {
                Spacer()
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 12, height: 8)
                    .rotationEffect(.degrees(180))
                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            }
        case .left:
            HStack(spacing: 0) {
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(-90))
                Spacer()
            }
        case .right:
            HStack(spacing: 0) {
                Spacer()
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(90))
            }
        }
    }

    private var arrowAlignment: Alignment {
        switch arrowDirection {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

// MARK: - Triangle Shape
/// 基础三角形形状
/// 负责绘制气泡提示组件的指向箭头，支持 2D 路径闭合
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - View Extension
extension View {
    /// 在视图上叠加一个引导提示浮层
    func tooltip(_ type: TooltipManager.TooltipType, isPresented: Binding<Bool>) -> some View {
        self.overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                WikiTooltip(
                    title: Localized.tr(type.titleKey),
                    description: Localized.tr(type.descriptionKey),
                    icon: type.icon,
                    arrowDirection: .top,
                    accentColor: .wikiAccent
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented.wrappedValue = false
                        TooltipManager.shared.markShown(type)
                    }
                }
            }
        }
    }
}
