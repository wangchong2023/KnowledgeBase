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
struct WikiToast: Identifiable, Equatable {
    let id = UUID()
    let type: WikiToastType
    let message: String
    var duration: Double = 3.0
}

// MARK: - Toast Manager
@MainActor
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
