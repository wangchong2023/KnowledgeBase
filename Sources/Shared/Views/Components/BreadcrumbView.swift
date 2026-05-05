// BreadcrumbView.swift
//
// 作者: Wang Chong
// 功能说明: 空间导航面包屑 (UX 视角：解决深度跳转后的心理迷失)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 空间导航面包屑视图
/// 负责展示知识页面的层级路径，支持快速回溯及深度跳转后的导航反馈
struct BreadcrumbView: View {
    let history: [WikiPage]
    let onNavigate: (UUID) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(history.enumerated()), id: \.element.id) { index, page in
                    HStack(spacing: 8) {
                        Button(action: { 
                            HapticFeedback.shared.trigger(.link)
                            onNavigate(page.id) 
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: page.displayIcon)
                                    .font(.system(size: 10))
                                Text(page.title)
                                    .font(.caption.weight(index == history.count - 1 ? .bold : .medium))
                            }
                            .foregroundStyle(index == history.count - 1 ? .wikiAccent : .wikiSecondary)
                        }
                        .buttonStyle(.plain)
                        
                        if index < history.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.wikiBorder)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.wikiBackground.opacity(0.8))
        .background(.ultraThinMaterial)
    }
}
