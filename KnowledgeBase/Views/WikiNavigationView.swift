import SwiftUI

// MARK: - Wiki Navigation (Main Wiki Browser)
struct WikiNavigationView: View {
    @EnvironmentObject var store: KMStore
    @Binding var selectedTab: ContentView.AppTab
    @State private var showCreateSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var tooltipManager = TooltipManager.shared

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            ZStack {
                if let pageID = store.selectedPageID,
                   let page = store.pageByID(pageID) {
                    PageDetailView(page: page)
                } else {
                    WikiWelcomeView(selectedTab: $selectedTab)
                }

                // 引导 Tooltip 浮层（首次使用引导）
                if tooltipManager.activeTooltip == .createPage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                WikiTooltip(
                                    title: Localized.tr(tooltipManager.activeTooltip?.titleKey ?? ""),
                                    description: Localized.tr(tooltipManager.activeTooltip?.descriptionKey ?? ""),
                                    icon: tooltipManager.activeTooltip?.icon ?? "questionmark",
                                    arrowDirection: .bottom,
                                    accentColor: .wikiAccent
                                )
                                Button(action: {
                                    withAnimation { tooltipManager.activeTooltip = nil }
                                }) {
                                    Text(Localized.tr("misc.gotIt"))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.wikiSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.wikiCard)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 100)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: tooltipManager.activeTooltip)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        store.undo()
                    } label: {
                        Label(Localized.tr("undo.undo"), systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!store.undoService.canUndo)

                    Button {
                        store.redo()
                    } label: {
                        Label(Localized.tr("undo.redo"), systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!store.undoService.canRedo)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!store.undoService.canUndo && !store.undoService.canRedo)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showCreateSheet = true
                    // 显示创建引导 Tooltip
                    if !tooltipManager.isShown(.createPage) {
                        withAnimation { tooltipManager.activeTooltip = .createPage }
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePageView()
        }
    }
}
