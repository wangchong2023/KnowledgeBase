import Foundation
import NaturalLanguage
import Accelerate

/// 商用级向量管理中心
/// 负责向量的异步计算、持久化同步以及基于 Accelerate 框架的高性能检索。
final class EmbeddingManager {
    private let core: SQLiteStoreCore
    private let embeddingModel: NLEmbedding?
    private let modelName = "apple_nl_v1"
    
    // 内存缓存，加速检索频率
    private var vectorCache: [UUID: [Float]] = [:]
    private let syncQueue = DispatchQueue(label: "com.workbuddy.embedding.sync", qos: .background)
    
    init(core: SQLiteStoreCore) {
        self.core = core
        self.embeddingModel = NLEmbedding.sentenceEmbedding(for: .chinese) ?? NLEmbedding.sentenceEmbedding(for: .english)
        loadCache()
    }
    
    private func loadCache() {
        vectorCache = core.selectAllEmbeddings()
    }
    
    // MARK: - 异步同步逻辑
    
    /// 同步所有待更新的页面向量
    func syncEmbeddings(pages: [WikiPage]) {
        syncQueue.async { [weak self] in
            guard let self = self, let model = self.embeddingModel else { return }
            
            for page in pages {
                // 检查缓存或数据库是否已存在且是最新的
                // 这里简化为：如果缓存不存在，则认为需要更新
                if self.vectorCache[page.id] == nil {
                    let text = "\(page.title)\n\(page.content.prefix(1000))"
                    if let vector = model.vector(for: text) {
                        let floatVector = vector.map { Float($0) }
                        self.core.saveEmbedding(id: page.id, embedding: floatVector, model: self.modelName)
                        self.vectorCache[page.id] = floatVector
                    }
                }
            }
        }
    }
    
    /// 当单个页面更新时触发
    func updateEmbedding(for page: WikiPage) {
        syncQueue.async { [weak self] in
            guard let self = self, let model = self.embeddingModel else { return }
            let text = "\(page.title)\n\(page.content.prefix(1000))"
            if let vector = model.vector(for: text) {
                let floatVector = vector.map { Float($0) }
                self.core.saveEmbedding(id: page.id, embedding: floatVector, model: self.modelName)
                self.vectorCache[page.id] = floatVector
            }
        }
    }
    
    // MARK: - 高性能检索 (Accelerate 加速)
    
    /// 为一组分块文本生成向量
    func vectorizeChunks(chunks: [String]) -> [[Float]] {
        guard let model = embeddingModel else { return [] }
        return chunks.map { text in
            model.vector(for: text)?.map { Float($0) } ?? [Float](repeating: 0, count: 512)
        }
    }
    
    /// 使用 Accelerate 框架进行向量余弦相似度检索
    func search(query: String, topK: Int = 20) -> [(id: UUID, score: Float)] {
        guard let model = embeddingModel, let queryVector = model.vector(for: query) else { return [] }
        let qv = queryVector.map { Float($0) }
        
        var results: [(UUID, Float)] = []
        
        for (id, vector) in vectorCache {
            let score = cosineSimilarity(vector, qv)
            if score > 0.1 {
                results.append((id, score))
            }
        }
        
        return results.sorted { $0.1 > $1.1 }.prefix(topK).map { $0 }
    }
    
    /// 利用 Accelerate 的 vDSP_dotpr 计算两个向量的点积（余弦相似度基础）
    private func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        guard v1.count == v2.count else { return 0 }
        
        var dotProduct: Float = 0
        vDSP_dotpr(v1, 1, v2, 1, &dotProduct, vDSP_Length(v1.count))
        
        var v1SumSq: Float = 0
        vDSP_svesq(v1, 1, &v1SumSq, vDSP_Length(v1.count))
        
        var v2SumSq: Float = 0
        vDSP_svesq(v2, 1, &v2SumSq, vDSP_Length(v2.count))
        
        let denominator = sqrt(v1SumSq) * sqrt(v2SumSq)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}
