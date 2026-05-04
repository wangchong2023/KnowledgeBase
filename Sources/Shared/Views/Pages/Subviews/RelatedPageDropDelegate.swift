import SwiftUI

// MARK: - Drop Delegate for Reordering
struct RelatedPageDropDelegate: DropDelegate {
    let item: WikiPage
    @Binding var page: WikiPage

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let fromItem = info.itemProviders(for: [.text]).first else { return }

        fromItem.loadObject(ofClass: NSString.self) { (uuidString, error) in
            guard let uuidString = uuidString as? String,
                  let fromID = UUID(uuidString: uuidString),
                  fromID != item.id else { return }

            DispatchQueue.main.async {
                let fromIndex = page.relatedPageIDs.firstIndex(of: fromID)
                let toIndex = page.relatedPageIDs.firstIndex(of: item.id)

                if let from = fromIndex, let to = toIndex {
                    withAnimation {
                        page.relatedPageIDs.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                    }
                }
            }
        }
    }
}
