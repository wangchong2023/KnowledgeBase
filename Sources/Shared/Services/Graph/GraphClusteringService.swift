import Foundation

/// 图谱聚类服务 (Architect 视角：知识涌现)
/// 负责对知识库中的页面进行语义聚类。
final class GraphClusteringService {

    struct Cluster: Identifiable {
        let id = UUID()
        let name: String
        let pageIDs: Set<UUID>
        let centroid: [Float]
        let colorName: String
    }
    
    /// 执行 K-Means 聚类
    func cluster(pages: [WikiPage], embeddings: [UUID: [Float]], k: Int = 5) -> [Cluster] {
        guard pages.count > k else { return [] }
        
        // 1. 初始化质心 (随机选 K 个)
        var centroids: [[Float]] = Array(embeddings.values.prefix(k))
        var clusters: [[UUID]] = Array(repeating: [], count: k)
        
        // 2. 迭代 (简单实现，实际可增加迭代次数限制)
        for _ in 0..<10 {
            clusters = Array(repeating: [], count: k)
            
            // 指派阶段
            for (id, vector) in embeddings {
                let nearestIndex = findNearestCentroid(vector: vector, centroids: centroids)
                clusters[nearestIndex].append(id)
            }
            
            // 更新阶段
            for i in 0..<k {
                if let newCentroid = calculateMean(vectors: clusters[i].compactMap { embeddings[$0] }) {
                    centroids[i] = newCentroid
                }
            }
        }
        
        // 3. 包装结果
        let clusterColors: [String] = ["blue", "purple", "orange", "green", "pink", "teal", "indigo"]
        
        return (0..<k).map { i in
            Cluster(
                name: Localized.trf("graph.cluster.name", i + 1),
                pageIDs: Set(clusters[i]),
                centroid: centroids[i],
                colorName: clusterColors[i % clusterColors.count]
            )
        }
    }
    
    private func findNearestCentroid(vector: [Float], centroids: [[Float]]) -> Int {
        var minDistance = Float.infinity
        var nearestIndex = 0
        for (i, centroid) in centroids.enumerated() {
            let dist = euclideanDistance(vector, centroid)
            if dist < minDistance {
                minDistance = dist
                nearestIndex = i
            }
        }
        return nearestIndex
    }
    
    private func euclideanDistance(_ v1: [Float], _ v2: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<min(v1.count, v2.count) {
            sum += pow(v1[i] - v2[i], 2)
        }
        return sqrt(sum)
    }
    
    private func calculateMean(vectors: [[Float]]) -> [Float]? {
        guard !vectors.isEmpty else { return nil }
        let count = Float(vectors.count)
        let length = vectors[0].count
        var mean = [Float](repeating: 0, count: length)
        for vector in vectors {
            for i in 0..<length {
                mean[i] += vector[i]
            }
        }
        return mean.map { $0 / count }
    }
}
