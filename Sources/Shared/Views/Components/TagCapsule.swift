// TagCapsule.swift
//
// 作者: Wang Chong
// 功能说明: struct TagCapsule
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

/// 知识标签胶囊组件
/// 提供一致的标签视觉样式，支持点击交互与删除操作
struct TagCapsule: View {
    let tag: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.caption2)
            Text(tag)
                .font(.subheadline.weight(.medium))
            Text("\(count)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.wikiAccent.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.wikiCard)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.wikiBorder, lineWidth: 1)
        )
        .foregroundStyle(.wikiText)
    }
}
