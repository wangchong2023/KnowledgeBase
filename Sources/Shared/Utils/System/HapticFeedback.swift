// HapticFeedback.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了系统级的触感反馈工具（HapticFeedback），旨在为用户提供标准化、语义化的触感反馈语言。
// 通过封装底层硬件接口，该组件实现了以下核心功能：
// 1. 定义了一套跨平台的触感模式枚举（HapticPattern），支持成功、失败、警告、处理中等多种交互语义。
// 2. 针对 macOS 和 iOS 进行了差异化适配，分别调用 NSHapticFeedbackManager 和 UINotificationFeedbackGenerator 等原生 API。
// 3. 建立了闭环的反馈机制，确保在知识金库加锁、AI 思考、链接建立等核心交互环节提供一致且细腻的震动体验。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/System 并重构，完善了符合架构规范的功能说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 系统级触感管理器 (Designer 视角：建立触感反馈语言)
@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()
    
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
