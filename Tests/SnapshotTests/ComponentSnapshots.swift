import XCTest
import SwiftUI
import SnapshotTesting
@testable import KM

final class ComponentSnapshots: XCTestCase {
    
    /// 测试 AI 脉搏指示器的视觉一致性
    func testAIPulseIndicator() {
        let view = AIPulseIndicator()
            .frame(width: 100, height: 100)
            .background(Color.wikiBackground)
        
        // 记录/验证 iOS 布局
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Pro)))
    }
    
    /// 测试图谱节点的视觉一致性
    func testGraphNodeView() {
        let node = GraphNode(
            id: UUID(),
            title: "测试节点",
            type: .concept,
            position: .zero
        )
        
        let view = GraphNodeView(
            node: node,
            isSelected: false,
            isAnimating: false,
            linkCount: 5,
            clusters: [],
            useClustering: false,
            onSelect: {},
            heroNamespace: Namespace().wrappedValue, // 仅用于预览/测试
            viewportRect: CGRect(x: 0, y: 0, width: 200, height: 200),
            scale: 1.0
        )
        .frame(width: 100, height: 100)
        .background(Color.wikiBackground)
        
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 100, height: 100)))
    }
}

// 辅助 Mock
private extension Namespace {
    var wrappedValue: Namespace.ID {
        @Environment(\.namespace) var ns
        return ns
    }
}

private struct NamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID = Namespace().wrappedValue
}

extension EnvironmentValues {
    var namespace: Namespace.ID {
        get { self[NamespaceKey.self] }
        set { self[NamespaceKey.self] = newValue }
    }
}
