import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag & Drop Support for KM
/// Enables drag and drop for page items in the knowledge base

// MARK: - Page Drag Item
/// Custom transfer type for page items
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
struct FileDropDelegate: DropDelegate {
    let onFileDrop: (URL) -> Void

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL])
    }
}