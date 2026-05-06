// Graph3DView.swift
//
// 作者: Wang Chong
// 功能说明: 基于 SceneKit 的 3D 知识图谱可视化视图。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-05
// 日期: 2026-05-05
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
import SceneKit

// MARK: - 3D 图谱容器
/// 3D 知识图谱视图
/// 负责在 3D 空间（SceneKit）中渲染知识节点与关联线条，提供力导向布局、自动旋转及空间交互体验
struct Graph3DView: View {
    @Environment(KMStore.self) var store
    @State private var scene: SCNScene?
    @State private var cameraDistance: Float = 140
    @State private var autoRotate = false
    @State private var filterType: PageType? = nil
    @State private var showNodeInfo = false
    @State private var infoPage: WikiPage?
    @State private var showPageDetail = false
    @State private var cameraNode: SCNNode?
    @Binding var selectedNodeID: UUID?
    @Binding var isFullScreen: Bool
    
    var body: some View {
        TappableSceneView(scene: scene) { uuid in
            handleNodeTap(uuid)
        }
        .onChange(of: selectedNodeID) { oldValue, newValue in
            buildScene()
        }
        .overlay(alignment: .topLeading) {
            if !isFullScreen {
                headerOverlay
                    .padding(.top, 16)
                    .padding(.leading, 20)
            }
        }
        .overlay(alignment: .topTrailing) {
            controlsOverlay
                .padding(.top, isFullScreen ? 40 : 8)
                .padding(.trailing, 16)
        }
        .overlay(alignment: .bottom) {
            if let page = infoPage {
                nodeInfoBar(page: page)
                    .padding(.bottom, isFullScreen ? 20 : 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background {
            if isFullScreen {
                Color.black
            } else {
                ZStack {
                    Color.wikiBackground
                    
                    // 高级感渐变背景：融合品牌色的星云感
                    LinearGradient(
                        colors: [
                            Color.wikiAccent.opacity(0.12),
                            Color.wikiAccent.opacity(0.04),
                            Color.clear,
                            Color.wikiAccent.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blur(radius: 50)
                    
                    // 辅助光晕
                    RadialGradient(
                        gradient: Gradient(colors: [Color.wikiAccent.opacity(0.08), Color.clear]),
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 500
                    )
                }
            }
        }
        .ignoresSafeArea(edges: isFullScreen ? .all : [])
        .statusBarHidden(isFullScreen)
        .preferredColorScheme(isFullScreen ? .dark : nil)
        .toolbar(isFullScreen ? .hidden : .visible, for: .tabBar)
#if os(iOS)
        .navigationBarBackButtonHidden(isFullScreen)
        .toolbar(isFullScreen ? .hidden : .visible, for: .navigationBar)
#endif
        .navigationDestination(isPresented: $showPageDetail) {
            if let page = infoPage {
                PageDetailView(page: page)
            }
        }
        .onAppear { 
            // 切换到 3D 图谱时，默认清空选中状态以隐藏卡片
            selectedNodeID = nil
            infoPage = nil
            showNodeInfo = false
            buildScene() 
        }
        .onChange(of: store.pages.count) { _, _ in buildScene() }
        .onChange(of: filterType) { _, _ in buildScene() }
    }
    
    private var headerOverlay: some View {
        VStack(alignment: isFullScreen ? .center : .leading, spacing: 4) {
            Text(L10n.Graph.ThreeD.tr("title"))
                .font(.subheadline.bold())
                .foregroundStyle(isFullScreen ? .white : .wikiText)
            
            if isFullScreen {
                Text(L10n.Graph.ThreeD.tr("desc"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(isFullScreen ? .center : .leading)
                    .frame(maxWidth: 240)
            }
        }
        .padding(.top, isFullScreen ? 20 : 0)
        .allowsHitTesting(false)
    }

    private var controlsOverlay: some View {
        Graph3DControlsOverlay(
            autoRotate: $autoRotate,
            filterType: $filterType,
            isFullScreen: $isFullScreen,
            onAutoRotateToggle: { 
                let newValue = !autoRotate
                autoRotate = newValue
                updateAutoRotation(isRotating: newValue) 
            },
            onResetCamera: { resetCamera() },
            onZoomIn: { zoom(in: true) },
            onZoomOut: { zoom(in: false) }
        )
    }

    private func nodeInfoBar(page: WikiPage) -> some View {
        Graph3DNodeInfoBar(page: page) {
            showPageDetail = true
        }
    }
    
    private func buildScene() {
        let newScene = SCNScene()
        // 仅在全屏模式下显示深空背景
        newScene.background.contents = isFullScreen ? UIColor.black : nil
        
        // 添加背景星尘
        addStarfield(to: newScene)

        setupLighting(scene: newScene)
        setupCamera(scene: newScene)

        let pages = filterType == nil ? store.pages : store.pages.filter { $0.type == filterType }
        guard !pages.isEmpty else {
            scene = newScene
            return
        }

        // 使用更动态的半径，确保节点不会过于拥挤
        let radius: CGFloat = CGFloat(max(30, min(100, pages.count * 10)))
        let positions = generateSpherePositions(count: pages.count, radius: radius)

        let nodeMap = createPageNodes(pages: pages, positions: positions, scene: newScene)
        createEdgeNodes(pages: pages, nodeMap: nodeMap, scene: newScene)
        addGridFloor(scene: newScene)

        scene = newScene
        
        // 动态调整相机距离：确保能看到整个球体
        let targetDistance = Float(radius) * 2.2
        cameraDistance = max(60, min(400, targetDistance))
        resetCamera() // 自动应用新距离并平滑对齐
        
        updateAutoRotation(isRotating: autoRotate)
    }

    private func addStarfield(to scene: SCNScene) {
        let starCount = 500
        let starGeometry = SCNSphere(radius: 0.1)
        starGeometry.firstMaterial?.emission.contents = UIColor(Color.wikiAccent).withAlphaComponent(0.8)
        starGeometry.firstMaterial?.diffuse.contents = UIColor(Color.wikiAccent).withAlphaComponent(0.5)
        
        for _ in 0..<starCount {
            let node = SCNNode(geometry: starGeometry)
            let r: Float = 150
            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: 0...(.pi))
            
            node.position = SCNVector3(
                r * sin(phi) * cos(theta),
                r * sin(phi) * sin(theta),
                r * cos(phi)
            )
            scene.rootNode.addChildNode(node)
        }
    }

    private func setupLighting(scene: SCNScene) {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.2, alpha: 1)
        scene.rootNode.addChildNode(ambientLight)

        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.color = UIColor(white: 1.0, alpha: 1)
        omniLight.position = SCNVector3(20, 30, 20)
        scene.rootNode.addChildNode(omniLight)
    }

    private func setupCamera(scene: SCNScene) {
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 1000 // 增加渲染范围以防远处节点被裁切
        camera.position = SCNVector3(0, 15, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
        camera.name = "mainCamera"
        scene.rootNode.addChildNode(camera)
        cameraNode = camera
    }

    private func createPageNodes(pages: [WikiPage], positions: [CGPoint3D], scene: SCNScene) -> [UUID: SCNNode] {
        var nodeMap: [UUID: SCNNode] = [:]
        
        // 计算邻居 ID 集合
        let neighborIDs: Set<UUID> = {
            guard let selectedID = selectedNodeID else { return [] }
            let connectedEdges = store.pages.flatMap { page in
                page.outgoingLinks.compactMap { link -> (UUID, UUID)? in
                    if let target = store.pages.first(where: { $0.title == link }) {
                        return (page.id, target.id)
                    }
                    return nil
                }
            }.filter { $0.0 == selectedID || $0.1 == selectedID }
            return Set(connectedEdges.flatMap { [$0.0, $0.1] })
        }()

        for (index, page) in pages.enumerated() {
            let nodeSize = calculateNodeSize(for: page)
            let geometry = createNodeGeometry(for: page.type, size: nodeSize)
            
            let isSelected = selectedNodeID == page.id
            let isNeighbor = neighborIDs.contains(page.id)
            let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
            
            let uiColor = UIColor(page.type.themedColor)
            let opacity: CGFloat = isDimmed ? 0.2 : 1.0
            
            geometry.firstMaterial?.diffuse.contents = uiColor.withAlphaComponent(opacity)
            geometry.firstMaterial?.specular.contents = UIColor.white.withAlphaComponent(opacity)
            geometry.firstMaterial?.emission.contents = isDimmed ? uiColor.withAlphaComponent(0.1) : uiColor.withAlphaComponent(0.4)

            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(
                Float(positions[index].x),
                Float(positions[index].y),
                Float(positions[index].z)
            )
            node.name = page.id.uuidString

            // 仅为选中点或邻居显示标签，或者节点总数较少时全部显示
            if !isDimmed || pages.count < 50 {
                let textNode = createLabelNode(title: page.title, nodeSize: nodeSize)
                textNode.opacity = isDimmed ? 0.4 : 1.0
                node.addChildNode(textNode)
            }

            if page.isPinned || isSelected {
                addPulseAnimation(to: node)
            }

            scene.rootNode.addChildNode(node)
            nodeMap[page.id] = node
        }

        return nodeMap
    }
    
    private func createNodeGeometry(for type: PageType, size: CGFloat) -> SCNGeometry {
        switch type {
        case .concept:
            return SCNSphere(radius: size)
        case .entity:
            return SCNBox(width: size * 1.6, height: size * 1.6, length: size * 1.6, chamferRadius: size * 0.2)
        case .source:
            return SCNCylinder(radius: size, height: size * 2.5)
        case .comparison:
            return SCNPyramid(width: size * 2, height: size * 2, length: size * 2)
        case .map:
            return SCNTorus(ringRadius: size, pipeRadius: size * 0.3)
        case .raw:
            return SCNBox(width: size * 2, height: size * 0.2, length: size * 1.5, chamferRadius: 0.05)
        }
    }

    private func calculateNodeSize(for page: WikiPage) -> CGFloat {
        let backlinkCount = store.pages.filter { $0.outgoingLinks.contains(page.title) }.count
        let linkCount = page.outgoingLinks.count + backlinkCount
        // 调大尺寸：基础尺寸从 0.6->1.2，增长系数从 0.2->0.4，最大上限从 2.0->4.0
        return CGFloat(max(1.2, min(4.0, 1.5 + Double(linkCount) * 0.4)))
    }

    private func createLabelNode(title: String, nodeSize: CGFloat) -> SCNNode {
        let text = SCNText(string: title, extrusionDepth: 0.1)
        text.font = UIFont.boldSystemFont(ofSize: 1.2)
        text.flatness = 0.2
        text.isWrapped = false

        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(Float(nodeSize + 0.5), 0, 0)
        textNode.scale = SCNVector3(0.4, 0.4, 0.4)
        textNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        textNode.geometry?.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.3)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]

        return textNode
    }

    private func addPulseAnimation(to node: SCNNode) {
        let pulseAction = SCNAction.customAction(duration: 2.0) { node, elapsedTime in
            let scale = 1.0 + 0.2 * sin(elapsedTime * .pi)
            node.scale = SCNVector3(scale, scale, scale)
        }
        node.runAction(SCNAction.repeatForever(pulseAction))
    }

    private func createEdgeNodes(pages: [WikiPage], nodeMap: [UUID: SCNNode], scene: SCNScene) {
        var processedEdges = Set<String>() // 用于去重已处理的边
        
        for page in pages {
            // 1. 处理出链
            for linkTitle in page.outgoingLinks {
                if let linkedPage = store.pages.first(where: { $0.title == linkTitle }),
                   let sourceNode = nodeMap[page.id],
                   let targetNode = nodeMap[linkedPage.id] {
                    
                    let edgeKey = [page.id.uuidString, linkedPage.id.uuidString].sorted().joined(separator: "-")
                    if !processedEdges.contains(edgeKey) && page.id != linkedPage.id {
                        let edge = createEdgeNode(from: sourceNode.position, to: targetNode.position, sourceID: page.id, targetID: linkedPage.id)
                        scene.rootNode.addChildNode(edge)
                        processedEdges.insert(edgeKey)
                    }
                }
            }
            
            // 2. 处理相关页面标识 (对应图谱布局处理逻辑)
            for relatedID in page.relatedPageIDs {
                if let targetNode = nodeMap[relatedID],
                   let sourceNode = nodeMap[page.id] {
                    
                    let edgeKey = [page.id.uuidString, relatedID.uuidString].sorted().joined(separator: "-")
                    if !processedEdges.contains(edgeKey) && page.id != relatedID {
                        let edge = createEdgeNode(from: sourceNode.position, to: targetNode.position, sourceID: page.id, targetID: relatedID)
                        scene.rootNode.addChildNode(edge)
                        processedEdges.insert(edgeKey)
                    }
                }
            }
        }
    }

    private func addGridFloor(scene: SCNScene) {
        let gridNode = createGridNode(size: 100, divisions: 50)
        gridNode.position = SCNVector3(0, -30, 0)
        scene.rootNode.addChildNode(gridNode)
    }
    
    private func generateSpherePositions(count: Int, radius: CGFloat) -> [CGPoint3D] {
        var positions: [CGPoint3D] = []
        let goldenRatio = (1 + sqrt(5)) / 2
        
        for i in 0..<count {
            let theta = 2 * .pi * CGFloat(i) / goldenRatio
            let phi = acos(1 - 2 * (CGFloat(i) + 0.5) / CGFloat(count))
            
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            
            positions.append(CGPoint3D(x: x, y: y, z: z))
        }
        
        return positions
    }
    
    private func createEdgeNode(from: SCNVector3, to: SCNVector3, sourceID: UUID, targetID: UUID) -> SCNNode {
        let source = SCNVector3(from.x, from.y, from.z)
        let target = SCNVector3(to.x, to.y, to.z)
        
        let vector = SCNVector3(target.x - source.x, target.y - source.y, target.z - source.z)
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        
        let isHighlighted = selectedNodeID == sourceID || selectedNodeID == targetID
        let radius: CGFloat = isHighlighted ? 0.15 : 0.05
        
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        let baseColor = UIColor(Color.wikiAccent)
        let opacity: CGFloat = isHighlighted ? 1.0 : 0.2
        
        cylinder.firstMaterial?.diffuse.contents = baseColor.withAlphaComponent(opacity)
        cylinder.firstMaterial?.emission.contents = isHighlighted ? baseColor.withAlphaComponent(0.8) : baseColor.withAlphaComponent(0.1)
        
        let node = SCNNode(geometry: cylinder)
        node.name = "edge_\(sourceID.uuidString)_\(targetID.uuidString)"
        node.position = SCNVector3(
            (source.x + target.x) / 2,
            (source.y + target.y) / 2,
            (source.z + target.z) / 2
        )
        
        let direction = SCNVector3(vector.x / length, vector.y / length, vector.z / length)
        let up = SCNVector3(0, 1, 0)
        let cross = SCNVector3(
            up.y * direction.z - up.z * direction.y,
            up.z * direction.x - up.x * direction.z,
            up.x * direction.y - up.y * direction.x
        )
        let dot = up.x * direction.x + up.y * direction.y + up.z * direction.z
        let crossLength = sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z)
        
        if crossLength > 0.001 {
            node.rotation = SCNVector4(cross.x / crossLength, cross.y / crossLength, cross.z / crossLength, acos(dot))
        }
        
        return node
    }
    
    private func createGridNode(size: Float, divisions: Int) -> SCNNode {
        let gridSize = CGFloat(size)
        let step = gridSize / CGFloat(divisions)
        var vertices: [SCNVector3] = []
        
        for i in 0...divisions {
            let offset = -gridSize / 2 + step * CGFloat(i)
            vertices.append(SCNVector3(Float(offset), 0, -size / 2))
            vertices.append(SCNVector3(Float(offset), 0, size / 2))
            vertices.append(SCNVector3(-size / 2, 0, Float(offset)))
            vertices.append(SCNVector3(size / 2, 0, Float(offset)))
        }
        
        let source = SCNGeometrySource(vertices: vertices)
        var indices: [Int32] = []
        for i in 0..<(vertices.count / 2) {
            indices.append(Int32(i * 2))
            indices.append(Int32(i * 2 + 1))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = UIColor(Color.wikiAccent).withAlphaComponent(0.2)
        
        return SCNNode(geometry: geometry)
    }
    
    private func resetCamera() {
        guard let camera = cameraNode else { return }
        HapticFeedback.shared.trigger(.selection)
        
        // 强制重置相机控制器的状态
        cameraDistance = 140 
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        camera.position = SCNVector3(0, 15, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
        SCNTransaction.commit()
    }
    
    private func zoom(in zoomingIn: Bool) {
        guard let camera = cameraNode else { return }
        let factor: Float = zoomingIn ? 0.8 : 1.25
        cameraDistance = max(20, min(300, cameraDistance * factor))
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        camera.position = SCNVector3(0, 15, Float(cameraDistance))
        SCNTransaction.commit()
    }
    
    private func handleNodeTap(_ uuid: UUID?) {
        if let uuid = uuid, let page = store.pages.first(where: { $0.id == uuid }) {
            selectedNodeID = uuid
            infoPage = page
            
            // 3D 空间对焦逻辑
            if let scene = scene, let targetNode = scene.rootNode.childNode(withName: uuid.uuidString, recursively: true), let camera = cameraNode {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.0
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                // 将相机移动到目标节点附近
                let pos = targetNode.position
                let direction = SCNVector3(pos.x, pos.y + 5, pos.z + 15) // 稍微偏移以获得良好的透视感
                camera.position = direction
                camera.look(at: pos)
                
                SCNTransaction.commit()
            }
            
            withAnimation(.spring()) {
                showNodeInfo = true
            }
        } else {
            // 点击空白处，清空选中状态
            selectedNodeID = nil
            infoPage = nil
            resetCamera()
            withAnimation(.spring()) {
                showNodeInfo = false
            }
        }
    }

    private func updateAutoRotation(isRotating: Bool) {
        guard let scene = scene else { return }
        scene.rootNode.removeAction(forKey: "autoRotate")
        if isRotating {
            // 优化：使用更短的单位旋转时长 (1s)，并开启线性计时模式以实现零延迟启动
            let rotate = SCNAction.rotateBy(x: 0, y: 0.2, z: 0, duration: 1.0)
            rotate.timingMode = .linear
            scene.rootNode.runAction(SCNAction.repeatForever(rotate), forKey: "autoRotate")
        }
    }
}
