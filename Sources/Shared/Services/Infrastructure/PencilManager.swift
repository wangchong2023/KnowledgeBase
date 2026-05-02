import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Apple Pencil 交互管理器 (Expert Design Item #3)
/// 支持双击切换工具（如在图谱中切换“全库”与“聚类”模式）。
@MainActor
final class PencilManager: NSObject {
    static let shared = PencilManager()
    
    private override init() {
        super.init()
        #if os(iOS)
        setupPencilInteraction()
        #endif
    }
    
    #if os(iOS)
    private var interaction: UIPencilInteraction?
    var onDoubleTap: (() -> Void)?
    
    private func setupPencilInteraction() {
        // 由于需要绑定到具体的 UIView，通常在 UIViewController 或 RootView 中注册
        // 这里提供一个全局可调用的逻辑闭包
    }
    #endif
    
    func register(to view: UIView) {
        #if os(iOS)
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
        #endif
    }
}

#if os(iOS)
extension PencilManager: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        // 响应双击
        LogService.shared.debug("✏️ Apple Pencil 双击触发")
        onDoubleTap?()
    }
}
#endif
