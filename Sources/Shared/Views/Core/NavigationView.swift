@preconcurrency import SwiftUI

@MainActor
struct NavigationView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: ContentView.AppTab
    var heroNamespace: Namespace.ID
    @State private var showCreateSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var tooltipManager = TooltipManager.shared

    var body: some View {
        @Bindable var store = store
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(heroNamespace: heroNamespace)
        } detail: {
            DetailContentView(selectedTab: $selectedTab, tooltipManager: tooltipManager, heroNamespace: heroNamespace)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func DetailContentView(selectedTab: Binding<ContentView.AppTab>, tooltipManager: TooltipManager, heroNamespace: Namespace.ID) -> some View {
        @Bindable var store = store
        NavigationStack(path: $store.navigationPath) {
            switch store.selectedTool {
            case .dashboard, .none:
                KnowledgeDashboardView()
            case .chat:
                Text("AI Chat") // 假设 AIChatView 在其他地方定义，若无则使用 Text
            case .taskCenter:
                Text("Task Center")
            case .index:
                SearchView()
            default:
                Text("Content")
            }
        }
        .navigationDestination(for: WikiPage.self) { page in
            PageDetailView(page: page)
        }
    }
}
