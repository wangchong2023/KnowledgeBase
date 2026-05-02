import SwiftUI
import SceneKit

// MARK: - Graph 3D View
/// 3D knowledge graph visualization using SceneKit.
/// Nodes float in 3D space, connected by edges, with force-directed layout.
struct Graph3DView: View {
    @EnvironmentObject var store: KMStore
    @State private var scene: SCNScene?
    @State private var selectedNodeID: UUID?
    @State private var cameraDistance: Float = 30
    @State private var autoRotate = true
    @State private var filterType: PageType? = nil
    @State private var showNodeInfo = false
    @State private var infoPage: WikiPage?
    /// 用于 resetCamera 的初始相机节点
    @State private var cameraNode: SCNNode?
    
    var body: some View {
        VStack(spacing: 0) {
            // 3D Scene
            TappableSceneView(scene: scene) { uuid in
                handleNodeTap(uuid)
            }
            .edgesIgnoringSafeArea(.all)
            .overlay(alignment: .topTrailing) {
                controlsOverlay
            }
            .overlay(alignment: .bottom) {
                if let page = infoPage {
                    nodeInfoBar(page: page)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("graph3d.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { buildScene() }
        .onChange(of: store.pages.count) { _, _ in buildScene() }
        .onChange(of: filterType) { _, _ in buildScene() }
    }
    
    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        Graph3DControlsOverlay(
            autoRotate: $autoRotate,
            filterType: $filterType,
            onAutoRotateToggle: { autoRotate.toggle(); updateAutoRotation() },
            onResetCamera: { resetCamera() }
        )
    }

    // MARK: - Node Info Bar
    private func nodeInfoBar(page: WikiPage) -> some View {
        Graph3DNodeInfoBar(page: page) {
            store.selectedPageID = page.id
        }
    }
    
    // MARK: - Build Scene
    private func buildScene() {
        let newScene = SCNScene()
        newScene.background.contents = UIColor(Color.wikiBackground)

        setupLighting(scene: newScene)
        setupCamera(scene: newScene)

        // Filter pages
        let pages = filterType == nil ? store.pages : store.pages.filter { $0.type == filterType }
        guard !pages.isEmpty else {
            scene = newScene
            return
        }

        // Generate 3D positions (sphere distribution)
        let positions = generateSpherePositions(count: pages.count, radius: CGFloat(cameraDistance) * 0.6)

        // Create nodes
        let nodeMap = createPageNodes(pages: pages, positions: positions, scene: newScene)

        // Create edges
        createEdgeNodes(pages: pages, nodeMap: nodeMap, scene: newScene)

        // Add grid floor
        addGridFloor(scene: newScene)

        scene = newScene
    }

    // MARK: - Setup Lighting
    private func setupLighting(scene: SCNScene) {
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.3, alpha: 1)
        scene.rootNode.addChildNode(ambientLight)

        // Omni light
        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.color = UIColor(white: 0.8, alpha: 1)
        omniLight.position = SCNVector3(0, 20, 20)
        scene.rootNode.addChildNode(omniLight)
    }

    // MARK: - Setup Camera
    private func setupCamera(scene: SCNScene) {
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 200
        camera.position = SCNVector3(0, 10, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camera)
        cameraNode = camera
    }

    // MARK: - Create Page Nodes
    private func createPageNodes(pages: [WikiPage], positions: [CGPoint3D], scene: SCNScene) -> [UUID: SCNNode] {
        var nodeMap: [UUID: SCNNode] = [:]

        for (index, page) in pages.enumerated() {
            let nodeSize = calculateNodeSize(for: page)
            let sphere = createSphereGeometry(size: nodeSize, color: page.type.themedColor)

            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(
                Float(positions[index].x),
                Float(positions[index].y),
                Float(positions[index].z)
            )
            node.name = page.id.uuidString

            // Add label
            let textNode = createLabelNode(title: page.title, nodeSize: nodeSize)
            node.addChildNode(textNode)

            // Pulse animation for pinned pages
            if page.isPinned {
                addPulseAnimation(to: node)
            }

            scene.rootNode.addChildNode(node)
            nodeMap[page.id] = node
        }

        return nodeMap
    }

    // MARK: - Calculate Node Size
    private func calculateNodeSize(for page: WikiPage) -> CGFloat {
        let backlinkCount = store.pages.filter { $0.outgoingLinks.contains(page.title) }.count
        let linkCount = page.outgoingLinks.count + backlinkCount
        return CGFloat(max(0.4, min(1.5, 0.5 + Double(linkCount) * 0.15)))
    }

    // MARK: - Create Sphere Geometry
    private func createSphereGeometry(size: CGFloat, color: Color) -> SCNSphere {
        let sphere = SCNSphere(radius: size)
        sphere.segmentCount = 24

        let uiColor = UIColor(color)
        sphere.firstMaterial?.diffuse.contents = uiColor
        sphere.firstMaterial?.specular.contents = UIColor(white: 0.5, alpha: 1)
        sphere.firstMaterial?.emission.contents = uiColor.withAlphaComponent(0.3)

        return sphere
    }

    // MARK: - Create Label Node
    private func createLabelNode(title: String, nodeSize: CGFloat) -> SCNNode {
        let text = SCNText(string: title, extrusionDepth: 0.1)
        text.font = UIFont.systemFont(ofSize: 1.0)
        text.flatness = 0.3
        text.isWrapped = false

        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(Float(nodeSize + 0.3), 0, 0)
        textNode.scale = SCNVector3(0.3, 0.3, 0.3)
        textNode.geometry?.firstMaterial?.diffuse.contents = UIColor(Color.wikiText).withAlphaComponent(0.8)
        textNode.geometry?.firstMaterial?.emission.contents = UIColor(Color.wikiText).withAlphaComponent(0.2)

        // Billboard constraint: always face camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]

        return textNode
    }

    // MARK: - Add Pulse Animation
    private func addPulseAnimation(to node: SCNNode) {
        let pulseAction = SCNAction.customAction(duration: 2.0) { node, elapsedTime in
            let scale = 1.0 + 0.15 * sin(elapsedTime * .pi)
            node.scale = SCNVector3(scale, scale, scale)
        }
        node.runAction(SCNAction.repeatForever(pulseAction))
    }

    // MARK: - Create Edge Nodes
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

    // MARK: - Add Grid Floor
    private func addGridFloor(scene: SCNScene) {
        let gridNode = createGridNode(size: 40, divisions: 20)
        gridNode.position = SCNVector3(0, -Float(cameraDistance) * 0.5, 0)
        scene.rootNode.addChildNode(gridNode)
    }
    
    // MARK: - Sphere Position Distribution (Fibonacci)
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
    
    // MARK: - Edge Node
    private func createEdgeNode(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let source = SCNVector3(from.x, from.y, from.z)
        let target = SCNVector3(to.x, to.y, to.z)
        
        let vector = SCNVector3(target.x - source.x, target.y - source.y, target.z - source.z)
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        
        let cylinder = SCNCylinder(radius: 0.03, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = UIColor(Color.wikiSecondary).withAlphaComponent(0.2)
        cylinder.firstMaterial?.emission.contents = UIColor(Color.wikiAccent).withAlphaComponent(0.1)
        
        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(
            (source.x + target.x) / 2,
            (source.y + target.y) / 2,
            (source.z + target.z) / 2
        )
        
        // Orient cylinder
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
    
    // MARK: - Grid Floor
    private func createGridNode(size: Float, divisions: Int) -> SCNNode {
        let gridSize = CGFloat(size)
        let step = gridSize / CGFloat(divisions)
        
        var vertices: [SCNVector3] = []
        
        for i in 0...divisions {
            let offset = -gridSize / 2 + step * CGFloat(i)
            // X lines
            vertices.append(SCNVector3(Float(offset), 0, -size / 2))
            vertices.append(SCNVector3(Float(offset), 0, size / 2))
            // Z lines
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
        geometry.firstMaterial?.diffuse.contents = UIColor(Color.wikiSecondary).withAlphaComponent(0.05)
        geometry.firstMaterial?.emission.contents = UIColor(Color.wikiSecondary).withAlphaComponent(0.02)
        
        return SCNNode(geometry: geometry)
    }
    
    // MARK: - Camera Control
    private func resetCamera() {
        guard let camera = cameraNode else { return }
        // Animate camera back to initial position
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        camera.position = SCNVector3(0, 10, Float(cameraDistance))
        camera.eulerAngles = SCNVector3(0, 0, 0)
        camera.look(at: SCNVector3(0, 0, 0))
        SCNTransaction.commit()
    }
    
    // MARK: - Node Tap Handler
    private func handleNodeTap(_ uuid: UUID) {
        selectedNodeID = uuid
        if let page = store.pages.first(where: { $0.id == uuid }) {
            infoPage = page
            withAnimation(.easeInOut(duration: 0.3)) {
                showNodeInfo = true
            }
        }
    }

    private func updateAutoRotation() {
        guard let scene = scene else { return }
        if autoRotate {
            let rotate = SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 10)
            scene.rootNode.runAction(SCNAction.repeatForever(rotate))
        } else {
            scene.rootNode.removeAllActions()
        }
    }
}
