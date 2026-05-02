import SwiftUI

// MARK: - Vision Pro Spatial View
/// Spatial computing views for Apple Vision Pro.
/// Provides immersive knowledge graph and page browsing in 3D space.
/// Uses conditional compilation to ensure compatibility on non-visionOS platforms.

#if os(visionOS)
import RealityKit
import RealityKitContent
#endif

struct VisionProSpatialView: View {
    @EnvironmentObject var store: KMStore
    @State private var orbitAngle: Angle = .degrees(0)
    @State private var showPageDetail = false
    @State private var selectedPage: WikiPage?
    
    var body: some View {
        #if os(visionOS)
        visionOSContent
        #else
        iOSPreviewContent
        #endif
    }
    
    // MARK: - visionOS Content
    #if os(visionOS)
    private var visionOSContent: some View {
        RealityView { content in
            // Create immersive scene
            let anchor = AnchorEntity(world: .zero)
            
            // Add nodes for each page
            let pages = store.pages
            let positions = generateSpatialPositions(count: pages.count)
            
            for (index, page) in pages.enumerated() {
                let entity = createPageEntity(page: page, position: positions[index])
                anchor.addChild(entity)
            }
            
            // Add connection lines
            for page in pages {
                for linkTitle in page.outgoingLinks {
                    if let linkedPage = store.pageByTitle(linkTitle),
                       let sourceIndex = pages.firstIndex(where: { $0.id == page.id }),
                       let targetIndex = pages.firstIndex(where: { $0.id == linkedPage.id }) {
                        let lineEntity = createConnectionLine(
                            from: positions[sourceIndex],
                            to: positions[targetIndex]
                        )
                        anchor.addChild(lineEntity)
                    }
                }
            }
            
            content.add(anchor)
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let pageID = value.entity.name.components(separatedBy: ":").last,
                       let uuid = UUID(uuidString: pageID),
                       let page = store.pageByID(uuid) {
                        selectedPage = page
                        showPageDetail = true
                    }
                }
        )
        .sheet(isPresented: $showPageDetail) {
            if let page = selectedPage {
                SpatialPageDetailView(page: page)
            }
        }
    }
    
    private func createPageEntity(page: WikiPage, position: SIMD3<Float>) -> ModelEntity {
        let size: Float = 0.15
        let mesh = MeshResource.generateSphere(radius: size)
        let color = UIColor(page.type.themedColor)
        var material = SimpleMaterial()
        material.color = .init(tint: color, opacity: 0.8)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        entity.name = "page:\(page.id.uuidString)"
        
        // Add hover component
        entity.components.set(HoverEffectComponent())
        
        return entity
    }
    
    private func createConnectionLine(from: SIMD3<Float>, to: SIMD3<Float>) -> ModelEntity {
        let distance = simd_distance(from, to)
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.005)
        var material = SimpleMaterial()
        material.color = .init(tint: .white.withAlphaComponent(0.3), opacity: 0.3)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        let midpoint = (from + to) / 2
        entity.position = midpoint
        
        // Orient toward target
        let direction = normalize(to - from)
        let up = SIMD3<Float>(0, 1, 0)
        let axis = normalize(cross(up, direction))
        let angle = acos(dot(up, direction))
        entity.orientation = simd_quatf(angle: angle, axis: axis)
        
        return entity
    }
    
    private func generateSpatialPositions(count: Int) -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []
        let radius: Float = 2.0
        let goldenRatio = (1 + sqrt(5)) / 2
        
        for i in 0..<count {
            let theta = 2 * .pi * Float(i) / Float(goldenRatio)
            let phi = acos(1 - 2 * (Float(i) + 0.5) / Float(count))
            
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            
            positions.append(SIMD3<Float>(x, y, z))
        }
        
        return positions
    }
    #endif
    
    // MARK: - iOS Preview Content
    /// On iOS, show a simulated spatial view preview with depth/parallax effects
    private var iOSPreviewContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "visionpro")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(Localized.tr("spatial.title"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.wikiText)
                    
                    Text(Localized.tr("spatial.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Parallax Preview
                SpatialParallaxPreview(pages: Array(store.pages.prefix(20)))
                    .frame(height: 400)
                
                // Feature List
                VStack(alignment: .leading, spacing: 12) {
                    Text(Localized.tr("spatial.features"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                    
                    SpatialFeatureRow(icon: "cube.transparent.fill", title: Localized.tr("spatial.feature.3dGraph"), desc: Localized.tr("spatial.feature.3dGraph.desc"))
                    SpatialFeatureRow(icon: "hand.tap.fill", title: Localized.tr("spatial.feature.gesture"), desc: Localized.tr("spatial.feature.gesture.desc"))
                    SpatialFeatureRow(icon: "eye.fill", title: Localized.tr("spatial.feature.gaze"), desc: Localized.tr("spatial.feature.gaze.desc"))
                    SpatialFeatureRow(icon: "person.crop.circle.badge.plus", title: Localized.tr("spatial.feature.spatialAudio"), desc: Localized.tr("spatial.feature.spatialAudio.desc"))
                }
                .padding()
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.largeRadius))
                
                // Device Requirement
                VStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text(Localized.tr("spatial.requirement"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding()
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("spatial.title"))
    }
}

// MARK: - Spatial Parallax Preview (iOS)
/// A simulated 3D parallax effect using layered cards with offset
struct SpatialParallaxPreview: View {
    let pages: [WikiPage]
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Background layers
                ForEach(0..<min(pages.count, 8), id: \.self) { i in
                    let page = pages[i]
                    let depth = CGFloat(i) * 3
                    let xOffset = dragOffset.width * depth * 0.01
                    let yOffset = dragOffset.height * depth * 0.01
                    let scale = 1.0 - CGFloat(i) * 0.03

                    // Distribute cards across the available area
                    let col = CGFloat(i % 4) - 1.5          // –1.5 … +1.5
                    let row = CGFloat(i / 4) - 0.5           // –0.5 … +0.5
                    let baseX = col * (w * 0.22)
                    let baseY = row * (h * 0.40)

                    SpatialNodeCard(page: page)
                        .scaleEffect(scale)
                        .offset(x: baseX + xOffset, y: baseY + yOffset)
                        .zIndex(Double(8 - i))
                }
            }
            .frame(width: w, height: h)
            .gesture(
                DragGesture()
                    .onChanged { value in dragOffset = value.translation }
                    .onEnded { _ in
                        withAnimation(.spring()) { dragOffset = .zero }
                    }
            )
            .background(
                RadialGradient(
                    colors: [Color.purple.opacity(0.1), Color.black.opacity(0.8)],
                    center: .center,
                    startRadius: 50,
                    endRadius: max(w, h) * 0.6
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.chipRadius))
        }
    }
}

// MARK: - Spatial Node Card
struct SpatialNodeCard: View {
    let page: WikiPage
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: page.displayIcon)
                .font(.title3)
                .foregroundStyle(page.type.themedColor)
            
            Text(page.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 100, height: 70)
        .background(
            RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                .fill(.ultraThinMaterial)
                .shadow(color: page.type.themedColor.opacity(0.3), radius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                .strokeBorder(page.type.themedColor.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Spatial Feature Row
struct SpatialFeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 36, height: 36)
                .background(Color.purple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
    }
}

// MARK: - Spatial Page Detail (visionOS only)
#if os(visionOS)
struct SpatialPageDetailView: View {
    let page: WikiPage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text(page.title)
                .font(.title2.weight(.bold))
            
            ScrollView {
                Text(page.content)
                    .font(.body)
            }
            
            Button(Localized.tr("misc.close")) { dismiss() }
        }
        .padding(40)
    }
}
#endif
