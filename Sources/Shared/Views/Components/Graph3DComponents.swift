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
        
        // 关键：如果场景中有指定的相机节点，则将其设为观察点
        if let scene = scene, let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            scnView.pointOfView = cameraNode
        }
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
        // 持续同步观察点，确保外部控制（缩放/重置）能生效
        if let scene = scene, let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            if uiView.pointOfView != cameraNode {
                uiView.pointOfView = cameraNode
            }
        }
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
        // 持续同步观察点
        if let scene = scene, let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            if nsView.pointOfView != cameraNode {
                nsView.pointOfView = cameraNode
            }
        }
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
    @Binding var isFullScreen: Bool

    let onAutoRotateToggle: () -> Void
    let onResetCamera: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Fullscreen toggle
            Button(action: { withAnimation(.spring()) { isFullScreen.toggle() } }) {
                Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundStyle(isFullScreen ? Color.wikiAccent : .wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-fullscreen")

            // Auto-rotate toggle
            Button(action: onAutoRotateToggle) {
                Image(systemName: autoRotate ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                    .font(.title3)
                    .foregroundStyle(autoRotate ? Color.wikiAccent : .wikiText)
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
            
            // Zoom In
            Button(action: onZoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-zoom-in")
            
            // Zoom Out
            Button(action: onZoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-zoom-out")

            // Filter
            Button(action: { withAnimation(.spring(response: 0.35)) { showFilterPopup.toggle() } }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(filterType == nil ? .wikiText : .white)
                    .padding(10)
                    .background(filterType == nil ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.wikiAccent))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(filterType == nil ? 0.1 : 0.3), radius: 4)
            }
            .overlay(alignment: .bottomTrailing) {
                if showFilterPopup {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Localized.tr("graph.filter"))
                            .font(.caption.bold())
                            .foregroundStyle(.wikiSecondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Button(action: { filterType = nil; showFilterPopup = false }) {
                                    HStack {
                                        Label(Localized.tr("graph.all"), systemImage: "square.grid.2x2")
                                        Spacer()
                                        if filterType == nil {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                        }
                                    }
                                    .padding()
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(filterType == nil ? Color.wikiAccent : .white)
                                
                                ForEach(PageType.allCases) { type in
                                    Button(action: { filterType = type; showFilterPopup = false }) {
                                        HStack {
                                            Label(type.displayName, systemImage: type.icon)
                                            Spacer()
                                            if filterType == type {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                            }
                                        }
                                        .padding()
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(filterType == type ? Color.wikiAccent : .white)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .frame(width: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.12)) // 非常深的灰色，接近背景但可区分
                            .shadow(color: .black.opacity(0.4), radius: 10, x: -5, y: 5)
                    )
                    .offset(x: -50, y: -20)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .accessibilityIdentifier("graph3d-filter")
        }
    }
    
    @State private var showFilterPopup = false
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
