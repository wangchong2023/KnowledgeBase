import SwiftUI
import SceneKit

// MARK: - Graph 3D View
/// 3D knowledge graph visualization using SceneKit.
/// Nodes float in 3D space, connected by edges, with force-directed layout.
struct Graph3DView: View {
    @Environment(KMStore.self) var store
    @State private var scene: SCNScene?
    @State private var selectedNodeID: UUID?
    @State private var cameraDistance: Float = 140 // 增加默认距离，确保边缘节点也能展示出来
    @State private var autoRotate = false // 默认关闭，由用户按需开启
    @State private var filterType: PageType? = nil
    @State private var showNodeInfo = false
    @State private var infoPage: WikiPage?
    @State private var showPageDetail = false
    @State private var cameraNode: SCNNode?
    @State private var isFullScreen = false
    
    var body: some View {
        TappableSceneView(scene: scene) { uuid in
            handleNodeTap(uuid)
        }
        .ignoresSafeArea(edges: isFullScreen ? .all : [])
        .overlay(alignment: .top) {
            if isFullScreen {
                headerOverlay
                    .padding(.top, 40)
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
        .background(Color.black)
        .preferredColorScheme(.dark)
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
        .onAppear { buildScene() }
        .onDisappear {
            store.selectedTool = nil
        }
        .onChange(of: store.pages.count) { _, _ in buildScene() }
        .onChange(of: filterType) { _, _ in buildScene() }
    }
    
    private var headerOverlay: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(Localized.tr("graph3d.title"))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            
            Text(Localized.tr("graph3d.desc"))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        }
        .allowsHitTesting(false)
    }

    private var controlsOverlay: some View {
        Graph3DControlsOverlay(
            autoRotate: $autoRotate,
            filterType: $filterType,
            isFullScreen: $isFullScreen,
            onAutoRotateToggle: { autoRotate.toggle(); updateAutoRotation() },
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
        // Deep space background
        newScene.background.contents = UIColor.black
        
        // Add stars
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
        updateAutoRotation()
    }

    private func addStarfield(to scene: SCNScene) {
        let starCount = 500
        let starGeometry = SCNSphere(radius: 0.1)
        starGeometry.firstMaterial?.emission.contents = UIColor.white
        
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
        camera.camera?.zFar = 1000 // Increased range to prevent cutting off distant nodes
        camera.position = SCNVector3(0, 15, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
        camera.name = "mainCamera"
        scene.rootNode.addChildNode(camera)
        cameraNode = camera
    }

    private func createPageNodes(pages: [WikiPage], positions: [CGPoint3D], scene: SCNScene) -> [UUID: SCNNode] {
        var nodeMap: [UUID: SCNNode] = [:]

        for (index, page) in pages.enumerated() {
            let nodeSize = calculateNodeSize(for: page)
            let geometry = createNodeGeometry(for: page.type, size: nodeSize)
            
            let uiColor = UIColor(page.type.themedColor)
            geometry.firstMaterial?.diffuse.contents = uiColor
            geometry.firstMaterial?.specular.contents = UIColor.white
            geometry.firstMaterial?.emission.contents = uiColor.withAlphaComponent(0.4)

            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(
                Float(positions[index].x),
                Float(positions[index].y),
                Float(positions[index].z)
            )
            node.name = page.id.uuidString

            let textNode = createLabelNode(title: page.title, nodeSize: nodeSize)
            node.addChildNode(textNode)

            if page.isPinned {
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
        return CGFloat(max(0.6, min(2.0, 0.8 + Double(linkCount) * 0.2)))
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
        for page in pages {
            for linkTitle in page.outgoingLinks {
                if let linkedPage = store.pages.first(where: { $0.title == linkTitle }),
                   let sourceNode = nodeMap[page.id],
                   let targetNode = nodeMap[linkedPage.id] {
                    let edge = createEdgeNode(from: sourceNode.position, to: targetNode.position)
                    scene.rootNode.addChildNode(edge)
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
    
    private func createEdgeNode(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let source = SCNVector3(from.x, from.y, from.z)
        let target = SCNVector3(to.x, to.y, to.z)
        
        let vector = SCNVector3(target.x - source.x, target.y - source.y, target.z - source.z)
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        
        let cylinder = SCNCylinder(radius: 0.05, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.1)
        cylinder.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.05)
        
        let node = SCNNode(geometry: cylinder)
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
        geometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.1)
        
        return SCNNode(geometry: geometry)
    }
    
    private func resetCamera() {
        guard let camera = cameraNode else { return }
        cameraDistance = 100
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
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
    
    private func handleNodeTap(_ uuid: UUID) {
        if let page = store.pages.first(where: { $0.id == uuid }) {
            selectedNodeID = uuid
            infoPage = page
            withAnimation(.spring()) {
                showNodeInfo = true
            }
        }
    }

    private func updateAutoRotation() {
        guard let scene = scene else { return }
        scene.rootNode.removeAction(forKey: "autoRotate")
        if autoRotate {
            // 加快旋转速度 (从 0.5 增加到 2.0)，增加视觉动感
            let rotate = SCNAction.rotateBy(x: 0, y: 2.0, z: 0, duration: 10)
            scene.rootNode.runAction(SCNAction.repeatForever(rotate), forKey: "autoRotate")
        }
    }
}
