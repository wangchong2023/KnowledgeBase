// Graph3DComponents.swift
//
// 作者: Wang Chong
// 功能说明: SceneKit 视图的可点击封装，支持节点点击检测
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

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
/// SceneKit 场景包装器组件
/// 负责在 SwiftUI 中嵌入 3D 渲染引擎，并实现基于点击位置的 3D 节点命中测试（Hit Test）
struct TappableSceneView: UIViewRepresentable {
    let scene: SCNScene?
    let onNodeTap: (UUID?) -> Void

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
        let onNodeTap: (UUID?) -> Void
        init(onNodeTap: @escaping (UUID?) -> Void) { self.onNodeTap = onNodeTap }

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
            onNodeTap(nil)
        }
    }
}
#elseif canImport(AppKit)
struct TappableSceneView: NSViewRepresentable {
    let scene: SCNScene?
    let onNodeTap: (UUID?) -> Void

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
        let onNodeTap: (UUID?) -> Void
        init(onNodeTap: @escaping (UUID?) -> Void) { self.onNodeTap = onNodeTap }

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
            onNodeTap(nil)
        }
    }
}
#endif

// MARK: - CGPoint3D
/// 3D 坐标点
/// 3D 坐标空间点模型
/// 负责定义节点在 SceneKit 笛卡尔坐标系中的 X/Y/Z 位置
struct CGPoint3D {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

// MARK: - Graph3D Controls Overlay
/// 3D 图谱控制面板：自动旋转/重置相机/筛选按钮
/// 3D 图谱控制面板组件
/// 负责提供相机对焦、全屏切换、自动旋转及页面类型过滤等空间导航控制功能
struct Graph3DControlsOverlay: View {
    @Binding var autoRotate: Bool
    @Binding var filterType: PageType?
    @Binding var isFullScreen: Bool

    let onAutoRotateToggle: () -> Void
    let onResetCamera: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        let iconColor: Color = isFullScreen ? .white : .wikiText
        
        VStack(spacing: 8) {
            // Fullscreen toggle
            Button(action: { 
                withAnimation(.spring()) { 
                    isFullScreen.toggle() 
                    showFilterPopup = false // 切换模式时自动折叠菜单
                } 
            }) {
                Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-fullscreen")

            // Auto-rotate toggle - 仅在全屏模式下显示
            if isFullScreen {
                Button(action: onAutoRotateToggle) {
                    Image(systemName: autoRotate ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                        .font(.title3)
                        .foregroundStyle(autoRotate ? Color.wikiAccent : iconColor)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("graph3d-auto-rotate")
            }

            // Reset camera
            Button(action: onResetCamera) {
                Image(systemName: "scope")
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-reset-camera")
            
            // Zoom In
            Button(action: onZoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-zoom-in")
            
            // Zoom Out
            Button(action: onZoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-zoom-out")

            // Filter - 全屏模式下根据用户要求隐藏
            if !isFullScreen {
                Button(action: { withAnimation(.spring(response: 0.35)) { showFilterPopup.toggle() } }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundStyle(filterType == nil ? iconColor : Color.wikiAccent)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(filterType == nil ? 0 : 0.2), radius: 4)
                }
                .overlay(alignment: .bottomTrailing) {
                    if showFilterPopup {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(L10n.Graph.tr("filter"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.wikiSecondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                                .padding(.bottom, 6)
                            
                            Divider().background(Color.wikiBorder.opacity(0.3))
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    Button(action: { filterType = nil; showFilterPopup = false }) {
                                        HStack {
                                            Image(systemName: "square.grid.2x2")
                                                .font(.system(size: 12))
                                            Text(L10n.Graph.tr("all"))
                                                .font(.system(size: 13))
                                            Spacer()
                                            if filterType == nil {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(filterType == nil ? Color.wikiAccent : .wikiText)
                                    
                                    ForEach(PageType.allCases) { type in
                                        Button(action: { filterType = type; showFilterPopup = false }) {
                                            HStack {
                                                Image(systemName: type.icon)
                                                    .font(.system(size: 12))
                                                Text(type.displayName)
                                                    .font(.system(size: 13))
                                                Spacer()
                                                if filterType == type {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(filterType == type ? Color.wikiAccent : .wikiText)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxHeight: 220) 
                        }
                        .frame(width: 140)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: -4, y: 4)
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
        .onChange(of: isFullScreen) { _, _ in
            showFilterPopup = false
        }
    }
    
    @State private var showFilterPopup = false
}

// MARK: - Graph3D Node Info Bar
/// 3D 图谱节点信息栏：显示选中节点的类型、标题和"查看页面"按钮
/// 3D 节点详情浮栏组件
/// 负责在选中 3D 节点时提供轻量级的信息摘要及进入详情页的快速入口
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
                Text(L10n.Graph.ThreeD.tr("viewPage"))
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
