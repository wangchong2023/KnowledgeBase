// DragDropComponents.swift
//
// 作者: Wang Chong
// 功能说明: Enables drag and drop for page items in the knowledge base
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag & Drop Support for KM
/// Enables drag and drop for page items in the knowledge base

// MARK: - Page Drag Item
/// Custom transfer type for page items
/// 页面拖拽传输模型
/// 负责在应用内或跨应用间传输 Wiki 页面的核心元数据，符合 Transferable 协议
struct PageDragItem: Transferable, Codable {
    let pageID: UUID
    let pageTitle: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: PageDragItem.self, contentType: .pageItem)
    }
}

extension UTType {
    static var pageItem: UTType {
        UTType(exportedAs: "com.km.app.pageItem")
    }
}

// MARK: - Drag & Drop Modifier for Pages
/// 页面拖放修饰符组件
/// 负责为视图注入原生拖拽支持，并提供自定义的拖拽实时预览效果
struct PageDragDropModifier: ViewModifier {
    let page: WikiPage

    func body(content: Content) -> some View {
        content
            .draggable(page.id.uuidString) {
                // Drag preview
                HStack {
                    Image(systemName: page.displayIcon)
                        .foregroundStyle(page.type.themedColor)
                    Text(page.title)
                        .font(.subheadline)
                }
                .padding(8)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
    }
}

extension View {
    /// Apply drag and drop support for a page
    func pageDragDrop(page: WikiPage) -> some View {
        modifier(PageDragDropModifier(page: page))
    }
}

// MARK: - Drop Delegate for Pages List
struct PagesListDropDelegate: DropDelegate {
    let onDrop: (UUID) -> Void

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        return true
    }
}

// MARK: - File Drop Delegate
/// Handles dropping external files (PDF, text) into the app
/// 外部文件投放代理组件
/// 负责处理从外部（如访达或桌面）投放至应用内的 PDF、文本等物理文件流
struct FileDropDelegate: DropDelegate {
    let onFileDrop: (URL) -> Void

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL])
    }
}