import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: KMStore
    @State private var expandedTypes: Set<PageType> = Set(PageType.allCases)
    @State private var showLogView = false
    @State private var showIndexView = false
    @State private var showLintView = false
    // MARK: - 常用知识清单（按关联密度 + 内容量综合评分，最多 5 条）
    private var frequentPages: [WikiPage] {
        let pinnedIDs = Set(store.pages.filter { $0.isPinned }.map { $0.id })
        return store.pages
            .filter { !pinnedIDs.contains($0.id) && !$0.content.isEmpty }
            .sorted {
                let scoreA = $0.outgoingLinks.count * 2 + $0.wordCount / 50
                let scoreB = $1.outgoingLinks.count * 2 + $1.wordCount / 50
                if scoreA != scoreB { return scoreA > scoreB }
                return $0.updated > $1.updated   // 同分时取最近修改
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        List(selection: $store.selectedPageID) {
            // ── 导航：总索引、操作日志、常用知识 ──
            Section {
                Button(action: { showIndexView = true }) {
                    Label("总索引", systemImage: "list.bullet.indent")
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("总索引")

                Button(action: { showLogView = true }) {
                    Label("操作日志", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.wikiSecondary)
                }
                .accessibilityIdentifier("操作日志")

                // 常用知识：显示前 3 条，点击直接跳转
                if !frequentPages.isEmpty {
                    Menu {
                        ForEach(frequentPages) { page in
                            Button(action: { store.selectedPageID = page.id }) {
                                HStack {
                                    Image(systemName: page.displayIcon)
                                        .foregroundStyle(page.type.themedColor)
                                    Text(page.title)
                                    Spacer()
                                    Text("\(page.outgoingLinks.count)链")
                                        .foregroundStyle(.wikiSecondary)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("常用知识")
                                .foregroundStyle(.wikiText)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    .tint(.orange)
                }
            } header: {
                Text("导航")
                    .foregroundStyle(.wikiSecondary)
            }

            // ── 已收藏 ──
            let pinnedPages = store.pages.filter { $0.isPinned }
            if !pinnedPages.isEmpty {
                Section {
                    ForEach(pinnedPages) { page in
                        PageSidebarRow(page: page)
                            .tag(page.id)
                    }
                } header: {
                    Label("已收藏", systemImage: "pin.fill")
                        .foregroundStyle(.wikiComparison)
                }
            }

            // ── 工具 ──
            Section {
                Button(action: { showLintView = true }) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(store.lintIssues.isEmpty ? .green : .orange)
                        Text("健康检查")
                            .foregroundStyle(.wikiText)
                        Spacer()
                        if !store.lintIssues.isEmpty {
                            Text("\(store.lintIssues.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .accessibilityIdentifier("健康检查")
            } header: {
                Text("工具")
                    .foregroundStyle(.wikiSecondary)
            }

            // ── 按类型分组（可折叠） ──
            ForEach(PageType.allCases) { type in
                let typePages = store.pages.filter { $0.type == type }
                if !typePages.isEmpty {
                    Section {
                        if expandedTypes.contains(type) {
                            ForEach(typePages) { page in
                                PageSidebarRow(page: page)
                                    .tag(page.id)
                            }
                        }
                    } header: {
                        Button(action: {
                            withAnimation {
                                if expandedTypes.contains(type) {
                                    expandedTypes.remove(type)
                                } else {
                                    expandedTypes.insert(type)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: expandedTypes.contains(type) ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.wikiSecondary)
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.themedColor)
                                Text(type.displayName)
                                    .foregroundStyle(.wikiText)
                                Spacer()
                                Text("\(typePages.count)")
                                    .font(.caption)
                                    .foregroundStyle(.wikiSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("知识库")
        .sheet(isPresented: $showLogView) {
            LogView()
        }
        .sheet(isPresented: $showIndexView) {
            IndexView()
        }
        .sheet(isPresented: $showLintView) {
            LintView()
        }
    }
}

// MARK: - Page Sidebar Row
struct PageSidebarRow: View {
    let page: WikiPage
    @EnvironmentObject var store: KMStore

    /// 内容摘要：取正文第一行非空文字（去掉 Markdown 标记符）
    private var snippet: String? {
        let stripped = page.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { line -> String in
                var s = String(line)
                // 去掉常见 Markdown 前缀：# ## ### - * >
                s = s.replacingOccurrences(of: #"^[#\-\*\>\s]+"#,
                                            with: "",
                                            options: .regularExpression)
                return s.trimmingCharacters(in: .whitespaces)
            } ?? ""
        return stripped.isEmpty ? nil : stripped
    }

    /// 字数展示：超过 1000 显示 k
    private var wordCountLabel: String {
        let n = page.wordCount
        return n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    var body: some View {
        Button(action: { store.selectedPageID = page.id }) {
            HStack(spacing: 10) {
                // 左侧：类型图标 + 状态色点
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: page.displayIcon)
                        .font(.system(size: 15))
                        .foregroundStyle(page.type.themedColor)
                        .frame(width: 30, height: 30)
                        .background(page.type.themedColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.sidebarRadius))

                    Circle()
                        .fill(page.status.color)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: 2)
                }

                // 右侧：主标题 + 摘要 + 元数据行
                VStack(alignment: .leading, spacing: 3) {
                    // 标题行
                    HStack(spacing: 4) {
                        Text(page.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.wikiText)
                            .lineLimit(1)

                        if page.isStub {
                            Text("stub")
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.yellow)
                        }

                        if page.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.wikiComparison)
                        }
                    }

                    // 摘要（有内容时才显示）
                    if let snippet = snippet {
                        Text(snippet)
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                            .lineLimit(1)
                    }

                    // 元数据行：字数 · 出链数 · 标签
                    HStack(spacing: 6) {
                        // 字数
                        if page.wordCount > 0 {
                            Label(wordCountLabel, systemImage: "text.alignleft")
                                .font(.system(size: 10))
                                .foregroundStyle(.wikiSecondary.opacity(0.8))
                        }

                        // 出链数
                        let linkCount = page.outgoingLinks.count
                        if linkCount > 0 {
                            Label("\(linkCount)", systemImage: "link")
                                .font(.system(size: 10))
                                .foregroundStyle(.wikiAccent.opacity(0.8))
                        }

                        // 最多显示 2 个标签
                        ForEach(page.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.wikiAccent.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundStyle(.wikiAccent.opacity(0.7))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
