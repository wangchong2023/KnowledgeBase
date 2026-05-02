import Foundation
import NaturalLanguage
import Accelerate

/// 商用级向量管理中心
/// 负责向量的异步计算、持久化同步以及基于 Accelerate 框架的高性能检索。
final class EmbeddingManager {
    private let core: SQLiteStoreCore
    private let embeddingModel: NLEmbedding?
    private let modelName = "apple_nl_v1"
    
    // 内存缓存与线程安全锁
    private var vectorCache: [UUID: [Float]] = [:]
    private let lock = NSRecursiveLock()
    private let syncQueue = DispatchQueue(label: "com.knowledge-management.embedding.sync", qos: .background)

    /// 所有嵌入向量（线程安全访问）
    var allEmbeddings: [UUID: [Float]] {
        lock.lock()
        defer { lock.unlock() }
        return vectorCache
    }
    
    init(core: SQLiteStoreCore) {
        self.core = core
        self.embeddingModel = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) ?? NLEmbedding.sentenceEmbedding(for: .english)
        loadCache()
    }
    
    private func loadCache() {
        let embeddings = core.selectAllEmbeddings()
        lock.lock()
        defer { lock.unlock() }
        vectorCache = embeddings
    }
    
    // MARK: - 异步同步逻辑
    
    /// 同步所有待更新的页面向量
    func syncEmbeddings(pages: [WikiPage]) {
        syncQueue.async { [weak self] in
            guard let self = self, let model = self.embeddingModel else { return }
            
            for page in pages {
                // 线程安全地读取缓存
                let needsUpdate: Bool = {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    return self.vectorCache[page.id] == nil
                }()
                
                if needsUpdate {
                    let text = "\(page.title)\n\(page.content.prefix(1000))"
                    
                    // 线程安全地调用模型
                    let vector: [Double]? = {
                        self.lock.lock()
                        defer { self.lock.unlock() }
                        return model.vector(for: text)
                    }()
                    
                    if let v = vector {
                        let floatVector = v.map { Float($0) }
                        self.core.saveEmbedding(id: page.id, embedding: floatVector, model: self.modelName)
                        
                        self.lock.lock()
                        self.vectorCache[page.id] = floatVector
                        self.lock.unlock()
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
            
            // 线程安全地调用模型
            let vector: [Double]? = {
                self.lock.lock()
                defer { self.lock.unlock() }
                return model.vector(for: text)
            }()
            
            if let v = vector {
                let floatVector = v.map { Float($0) }
                self.core.saveEmbedding(id: page.id, embedding: floatVector, model: self.modelName)
                
                self.lock.lock()
                self.vectorCache[page.id] = floatVector
                self.lock.unlock()
            }
        }
    }
    
    // MARK: - 高性能检索 (Accelerate 加速)
    
    /// 为一组分块文本生成向量
    func vectorizeChunks(chunks: [String]) -> [[Float]] {
        guard let model = embeddingModel else { return [] }
        return chunks.map { text in
            self.lock.lock()
            let v = model.vector(for: text)
            self.lock.unlock()
            return v?.map { Float($0) } ?? [Float](repeating: 0, count: 512)
        }
    }
    
    /// 使用 Accelerate 框架进行向量余弦相似度检索
    func search(query: String, topK: Int = 20) -> [(id: UUID, score: Float)] {
        guard let model = embeddingModel else { return [] }
        
        // 线程安全地获取查询向量
        let queryVector: [Double]? = {
            lock.lock()
            defer { lock.unlock() }
            return model.vector(for: query)
        }()
        
        guard let qvRaw = queryVector else { return [] }
        let qv = qvRaw.map { Float($0) }
        
        var results: [(UUID, Float)] = []
        
        // 线程安全地获取当前缓存快照
        let currentCache: [UUID: [Float]] = {
            lock.lock()
            defer { lock.unlock() }
            return vectorCache
        }()
        
        for (id, vector) in currentCache {
            let score = cosineSimilarity(vector, qv)
            if score > 0.35 {
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
        guard denominator > 0 else { return 0 }
        return dotProduct / denominator
    }

    /// 计算两个向量的余弦相似度（静态方法，可从外部调用）
    static func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        guard v1.count == v2.count else { return 0 }

        var dotProduct: Float = 0
        vDSP_dotpr(v1, 1, v2, 1, &dotProduct, vDSP_Length(v1.count))

        var v1SumSq: Float = 0
        vDSP_svesq(v1, 1, &v1SumSq, vDSP_Length(v1.count))

        var v2SumSq: Float = 0
        vDSP_svesq(v2, 1, &v2SumSq, vDSP_Length(v2.count))

        let denominator = sqrt(v1SumSq) * sqrt(v2SumSq)
        guard denominator > 0 else { return 0 }
        return dotProduct / denominator
    }
}
