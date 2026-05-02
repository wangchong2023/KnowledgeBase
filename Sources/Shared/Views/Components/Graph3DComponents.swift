import SwiftUI
import SceneKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Tappable Scene View Representable
/// SceneKit 视图的可点击封装，支持节点点击检测
#if canImport(UIKit)
@MainActor
struct TappableSceneView: UIViewRepresentable {
    let scene: SCNScene?
    let onNodeTap: (UUID) -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .clear
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
    }

    func makeCoordinator() -> Coordinator { Coordinator(onNodeTap: onNodeTap) }

    @MainActor class Coordinator: NSObject {
        let onNodeTap: (UUID) -> Void
        init(onNodeTap: @escaping (UUID) -> Void) { self.onNodeTap = onNodeTap }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  scnView.scene != nil else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for result in hitResults {
                if let name = result.node.name, let uuid = UUID(uuidString: name) {
                    onNodeTap(uuid); return
                }
                if let parentName = result.node.parent?.name, let uuid = UUID(uuidString: parentName) {
                    onNodeTap(uuid); return
                }
            }
        }
    }
}
#elseif canImport(AppKit)
struct TappableSceneView: NSViewRepresentable {
    let scene: SCNScene?
    let onNodeTap: (UUID) -> Void

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .clear
        let tapGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = scene
    }

    func makeCoordinator() -> Coordinator { Coordinator(onNodeTap: onNodeTap) }

    class Coordinator: NSObject {
        let onNodeTap: (UUID) -> Void
        init(onNodeTap: @escaping (UUID) -> Void) { self.onNodeTap = onNodeTap }

        @objc func handleTap(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  scnView.scene != nil else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for result in hitResults {
                if let name = result.node.name, let uuid = UUID(uuidString: name) {
                    onNodeTap(uuid); return
                }
                if let parentName = result.node.parent?.name, let uuid = UUID(uuidString: parentName) {
                    onNodeTap(uuid); return
                }
            }
        }
    }
}
#endif

// MARK: - CGPoint3D
/// 3D 坐标点
struct CGPoint3D {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

// MARK: - Graph3D Controls Overlay
/// 3D 图谱控制面板：自动旋转/重置相机/筛选按钮
struct Graph3DControlsOverlay: View {
    @Binding var autoRotate: Bool
    @Binding var filterType: PageType?

    let onAutoRotateToggle: () -> Void
    let onResetCamera: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Auto-rotate toggle
            Button(action: onAutoRotateToggle) {
                Image(systemName: autoRotate ? "rotate.3d.fill" : "rotate.3d")
                    .font(.title3)
                    .foregroundStyle(.wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-auto-rotate")

            // Reset camera
            Button(action: onResetCamera) {
                Image(systemName: "scope")
                    .font(.title3)
                    .foregroundStyle(.wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-reset-camera")

            // Filter
            Menu {
                Button(Localized.tr("graph.all")) { filterType = nil }
                ForEach(PageType.allCases) { type in
                    Button(action: { filterType = type }) {
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(.wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-filter")
        }
        .padding(.trailing, 16)
        .padding(.top, 8)
    }
}

// MARK: - Graph3D Node Info Bar
/// 3D 图谱节点信息栏：显示选中节点的类型、标题和"查看页面"按钮
struct Graph3DNodeInfoBar: View {
    let page: WikiPage
    let onViewPage: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(page.type.themedColor)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: page.displayIcon)
                        .font(.caption)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                Text(page.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }

            Spacer()

            Button(action: onViewPage) {
                Text(Localized.tr("graph3d.viewPage"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.wikiAccent.opacity(0.15))
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("graph3d-view-page")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.largeRadius))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
