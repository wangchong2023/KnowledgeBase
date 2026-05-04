import SwiftUI

// MARK: - Keyboard Shortcuts View Modifier

struct KeyboardShortcutsViewModifier: ViewModifier {
    @Environment(KMStore.self) var store
    @State private var showCreateSheet = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showCreateSheet) {
                CreatePageView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .createNewPage)) { _ in
                showCreateSheet = true
            }
    }
}

extension View {
    func withKeyboardShortcuts() -> some View {
        modifier(KeyboardShortcutsViewModifier())
    }
}
