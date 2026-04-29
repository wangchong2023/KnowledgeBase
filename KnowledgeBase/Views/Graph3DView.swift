import SwiftUI
import SceneKit
import UIKit

// MARK: - Tappable Scene View Representable
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

    func makeCoordinator() -> Coordinator {
        Coordinator(onNodeTap: onNodeTap)
    }

    class Coordinator: NSObject {
        let onNodeTap: (UUID) -> Void

        init(onNodeTap: @escaping (UUID) -> Void) {
            self.onNodeTap = onNodeTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  let scene = scnView.scene else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for result in hitResults {
                if let name = result.node.name, let uuid = UUID(uuidString: name) {
                    onNodeTap(uuid)
                    return
                }
                // Check parent node (text labels are children of the sphere)
                if let parentName = result.node.parent?.name,
                   let uuid = UUID(uuidString: parentName) {
                    onNodeTap(uuid)
                    return
                }
            }
        }
    }
}

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
        .navigationTitle(L.tr("graph3d.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { buildScene() }
        .onChange(of: store.pages.count) { _, _ in buildScene() }
        .onChange(of: filterType) { _, _ in buildScene() }
    }
    
    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        VStack(spacing: 8) {
            // Auto-rotate toggle
            Button(action: { autoRotate.toggle(); updateAutoRotation() }) {
                Image(systemName: autoRotate ? "rotate.3d.fill" : "rotate.3d")
                    .font(.title3)
                    .foregroundStyle(.wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            // Reset camera
            Button(action: { resetCamera() }) {
                Image(systemName: "scope")
                    .font(.title3)
                    .foregroundStyle(.wikiText)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            // Filter
            Menu {
                Button(L.tr("graph.all")) { filterType = nil }
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
        }
        .padding(.trailing, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Node Info Bar
    private func nodeInfoBar(page: WikiPage) -> some View {
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
            
            Button(action: {
                store.selectedPageID = page.id
            }) {
                Text(L.tr("graph3d.viewPage"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.wikiAccent.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.largeRadius))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Build Scene
    private func buildScene() {
        let newScene = SCNScene()
        newScene.background.contents = UIColor(Color.wikiBackground)

        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.3, alpha: 1)
        newScene.rootNode.addChildNode(ambientLight)

        // Omni light
        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.color = UIColor(white: 0.8, alpha: 1)
        omniLight.position = SCNVector3(0, 20, 20)
        newScene.rootNode.addChildNode(omniLight)

        // Camera node for programmatic control
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 200
        camera.position = SCNVector3(0, 10, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
        newScene.rootNode.addChildNode(camera)
        cameraNode = camera

        // Filter pages
        let pages = filterType == nil ? store.pages : store.pages.filter { $0.type == filterType }
        guard !pages.isEmpty else {
            scene = newScene
            return
        }
        
        // Generate 3D positions (sphere distribution)
        let positions = generateSpherePositions(count: pages.count, radius: CGFloat(cameraDistance) * 0.6)
        
        // Create nodes
        var nodeMap: [UUID: SCNNode] = [:]
        
        for (index, page) in pages.enumerated() {
            let nodeSize: CGFloat = {
                let linkCount = page.outgoingLinks.count + store.backlinks(for: page.id).count
                return CGFloat(max(0.4, min(1.5, 0.5 + Double(linkCount) * 0.15)))
            }()
            
            let sphere = SCNSphere(radius: nodeSize)
            sphere.segmentCount = 24
            
            let color = UIColor(page.type.themedColor)
            sphere.firstMaterial?.diffuse.contents = color
            sphere.firstMaterial?.specular.contents = UIColor(white: 0.5, alpha: 1)
            sphere.firstMaterial?.emission.contents = color.withAlphaComponent(0.3)
            
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(
                Float(positions[index].x),
                Float(positions[index].y),
                Float(positions[index].z)
            )
            node.name = page.id.uuidString
            
            // Add label (text node)
            let text = SCNText(string: page.title, extrusionDepth: 0.1)
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
            
            node.addChildNode(textNode)
            
            // Pulse animation for pinned pages
            if page.isPinned {
                let pulseAction = SCNAction.customAction(duration: 2.0) { node, elapsedTime in
                    let scale = 1.0 + 0.15 * sin(elapsedTime * .pi)
                    node.scale = SCNVector3(scale, scale, scale)
                }
                node.runAction(SCNAction.repeatForever(pulseAction))
            }
            
            newScene.rootNode.addChildNode(node)
            nodeMap[page.id] = node
        }
        
        // Create edges
        for page in pages {
            for linkTitle in page.outgoingLinks {
                if let linkedPage = store.pageByTitle(linkTitle),
                   let sourceNode = nodeMap[page.id],
                   let targetNode = nodeMap[linkedPage.id] {
                    let edge = createEdgeNode(from: sourceNode.position, to: targetNode.position)
                    newScene.rootNode.addChildNode(edge)
                }
            }
        }
        
        // Add a subtle grid floor
        let gridNode = createGridNode(size: 40, divisions: 20)
        gridNode.position = SCNVector3(0, -Float(cameraDistance) * 0.5, 0)
        newScene.rootNode.addChildNode(gridNode)
        
        scene = newScene
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

// MARK: - Helper
private struct CGPoint3D {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}
