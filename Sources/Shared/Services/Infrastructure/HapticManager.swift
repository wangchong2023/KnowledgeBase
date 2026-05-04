// HapticManager.swift
//
// 作者: Wang Chong
// 功能说明: 系统级触感管理器 (Designer 视角：建立触感反馈语言)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 系统级触感管理器 (Designer 视角：建立触感反馈语言)
@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    enum HapticPattern {
        case success    // 操作成功
        case error      // 操作失败或拒绝
        case warning    // 警告
        case processing // AI 正在处理
        case lock       // 金库加锁
        case unlock     // 金库解锁
        case link       // 链接建立
        case selection  // UI 选择反馈
        case pulse      // AI 思考脉搏 (循环轻触)
    }
    
    /// 触发指定模式的触感反馈
    func trigger(_ pattern: HapticPattern) {
        #if os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch pattern {
        case .success, .unlock:
            performer.perform(.alignment, performanceTime: .now)
        case .error, .warning, .lock:
            performer.perform(.levelChange, performanceTime: .now)
        case .processing, .link, .selection, .pulse:
            performer.perform(.generic, performanceTime: .now)
        }
        #elseif os(iOS)
        switch pattern {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .lock:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .unlock:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .processing, .link, .selection, .pulse:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}
