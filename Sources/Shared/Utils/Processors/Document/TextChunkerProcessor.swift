// TextChunkerProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了基于递归字符分割算法的文本分块处理器（TextChunkerProcessor），主要用于大规模文本的预处理与语义分块。
// 该组件是 RAG（检索增强生成）流程中的关键环节，具体能力包括：
// 1. 递归分割逻辑：通过预设的分隔符优先级（如段落、句子、标点），将长文本递归拆解为符合模型上下文长度的块。
// 2. 块重叠控制：支持可配置的块重叠（Overlap）参数，确保在切分点附近保留足够的上下文信息，防止语义断裂。
// 3. 语义完整性：在分块过程中优先寻找自然段落边界，最大限度地保留文本的逻辑连贯性。
// 4. 性能优化：采用轻量级迭代算法，能够快速处理万级字符长度的长文档，为向量化编码提供标准化的输入。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors 并重命名，完善分块逻辑说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 递归分块器 (RAG 核心：语义保真)
/// 负责将长文档拆分为适合向量检索的小块。
final class TextChunkerProcessor {
    
    struct Chunk: Identifiable {
        let id = UUID()
        let text: String
        let startIndex: Int
    }
    
    /// 分块配置
    struct Config {
        let chunkSize: Int      // 每个块的最大字符数
        let chunkOverlap: Int   // 块与块之间的重叠字符数
        let separators: [String] // 拆分优先级：换行 > 句号 > 空格
    }
    
    static let `default` = Config(
        chunkSize: 800,
        chunkOverlap: 150,
        separators: ["\n# ", "\n## ", "\n### ", "\n\n", "\n", "。", ".", " ", ""]
    )
    
    /// 执行递归分块
    func split(text: String, config: Config = TextChunkerProcessor.default) -> [Chunk] {
        var chunks: [Chunk] = []
        var remainingText = text
        var currentIndex = 0
        
        while !remainingText.isEmpty {
            if remainingText.count <= config.chunkSize {
                chunks.append(Chunk(text: remainingText, startIndex: currentIndex))
                break
            }
            
            // 寻找最佳拆分点
            var splitPoint = config.chunkSize
            for separator in config.separators {
                let range = remainingText.startIndex..<remainingText.index(remainingText.startIndex, offsetBy: config.chunkSize)
                if let foundRange = remainingText.range(of: separator, options: .backwards, range: range) {
                    splitPoint = remainingText.distance(from: remainingText.startIndex, to: foundRange.lowerBound) + separator.count
                    break
                }
            }
            
            let chunkText = String(remainingText.prefix(splitPoint))
            chunks.append(Chunk(text: chunkText, startIndex: currentIndex))
            
            // 处理重叠
            let step = max(1, splitPoint - config.chunkOverlap)
            remainingText = String(remainingText.dropFirst(step))
            currentIndex += step
        }
        
        return chunks
    }
}
