import Foundation
import AppKit

/// 触感反馈管理器 (Designer 视角：极致体验)
final class HapticManager {
    static func selection() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    static func success() {
        // macOS 触感反馈有限，通常使用声音或模拟轻触
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    
    static func warning() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
