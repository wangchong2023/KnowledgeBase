// WikiToast.swift
//
// 作者: Wang Chong
// 功能说明: enum WikiToastType
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Combine

// MARK: - Wiki Toast Type
/// 轻提示类型枚举
/// 负责定义 Toast 的视觉风格（图标与色彩）及其代表的业务状态
enum WikiToastType: Equatable {
    case success
    case error
    case info
    case processing
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .processing: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .wikiAccent
        case .processing: return .wikiAccent
        }
    }
}

// MARK: - Wiki Toast Model
/// 轻提示数据模型
/// 负责封装单条 Toast 的展示内容、类型标识及显示时长，具备唯一标识符
struct WikiToast: Identifiable, Equatable {
    let id = UUID()
    let type: WikiToastType
    let message: String
    var duration: Double = 3.0
}

// MARK: - 提示管理器
@MainActor
/// 轻提示全局管理单例
/// 负责 Toast 的队列调度、生命周期计时（自动隐藏）及并发状态管理，确保 UI 层的非阻塞反馈
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: WikiToast?
    private var timer: AnyCancellable?
    
    private init() {}
    
    func show(type: WikiToastType, message: String, duration: Double = 3.0) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = WikiToast(type: type, message: message, duration: duration)
        }
        
        timer?.cancel()
        if duration > 0 {
            timer = Just(())
                .delay(for: .seconds(duration), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    self?.dismiss()
                }
        }
    }
    
    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = nil
        }
    }
}

// MARK: - Wiki Toast View
/// 系统轻提示（Toast）组件
/// 提供非侵入式的状态反馈信息，支持成功、错误、警告等多种语义化样式
/// 轻提示（Toast）视觉组件
/// 负责在界面顶部提供非侵入式的即时反馈，支持模糊背板与弹性入场动画
struct WikiToastView: View {
    let toast: WikiToast
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if toast.type == .processing {
                ProgressView()
                    .tint(toast.type.color)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: toast.type.icon)
                    .foregroundStyle(toast.type.color)
            }
            
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.wikiText)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.wikiCard.opacity(0.7))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.wikiBorder.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - View Modifier
/// 轻提示视图修饰符
/// 负责将 Toast 展示层注入到视图树的最顶层，实现跨页面的即时消息提示能力
struct WikiToastModifier: ViewModifier {
    @StateObject private var manager = ToastManager.shared
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let toast = manager.currentToast {
                WikiToastView(toast: toast) {
                    manager.dismiss()
                }
                .padding(.top, 10)
                .zIndex(9999)
            }
        }
    }
}

extension View {
    func wikiToast() -> some View {
        modifier(WikiToastModifier())
    }
}
