// SnapshotHelper.swift
//
// 作者: Wang Chong
// 功能说明: 轻量级快照测试助手
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 轻量级快照测试助手
/// 原理：将视图渲染为 Image，并对比 Base64 哈希值
final class SnapshotHelper {
    
    /// 验证视图是否与参考快照一致
    @MainActor
    static func verifyView<V: View>(_ view: V, named name: String) -> Bool {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // 使用 Retina 分辨率
        
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else {
            return false
        }
        
        let currentHash = data.base64EncodedString().count // 简易哈希：使用长度作为初步校验
        
        // 1. 获取参考快照路径
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let refURL = docs.appendingPathComponent("snapshots/\(name).ref")
        
        // 2. 如果不存在参考快照，则记录当前快照为参考（录制模式）
        if !FileManager.default.fileExists(atPath: refURL.path) {
            try? FileManager.default.createDirectory(at: refURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: refURL)
            print("📸 [Snapshot] 参考快照已录制: \(name)")
            return true
        }
        
        // 3. 读取参考快照并对比
        let refData = try? Data(contentsOf: refURL)
        if data == refData {
            print("✅ [Snapshot] \(name) 验证通过！")
            return true
        } else {
            print("❌ [Snapshot] \(name) 验证失败！视觉出现偏差。")
            return false
        }
    }
}
