// RecursiveChunker.swift
//
// 作者: Wang Chong
// 功能说明: 递归分块器 (RAG 核心：语义保真)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

/// 递归分块器 (RAG 核心：语义保真)
/// 负责将长文档拆分为适合向量检索的小块。
final class RecursiveChunker {
    
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
    func split(text: String, config: Config = RecursiveChunker.default) -> [Chunk] {
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
