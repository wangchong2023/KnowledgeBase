import SwiftUI
import UIKit

/// 待执行的编辑器操作
///
/// 用于 toolbar 和 representable 之间的通信。
/// 当用户点击工具栏按钮时，将操作类型写入此枚举，
/// 由 representable 消费并执行具体的文本操作（插入、包裹等）。
///
/// - insert: 在光标位置插入前缀和可选后缀
/// - wrap: 用指定字符串包裹选区
/// - insertMultiline: 在光标位置插入多行文本
/// - wikilink: 打开页面链接选择器
enum EditorPendingAction: Equatable {
    case insert(prefix: String, suffix: String?)
    case wrap(wrapper: String)
    case insertMultiline(text: String)
    case wikilink
}

/// Markdown 富文本编辑器视图
///
/// 支持编辑知识库页面的 Markdown 内容，包括标题、标签、别名和正文。
///
/// ## 主要功能
/// - 页面标题编辑
/// - 标签管理（添加、删除）
/// - 别名管理（添加、删除）
/// - Markdown 内容编辑（支持富文本工具栏）
/// - Wiki 链接插入
///
/// ## 状态管理
/// - `editorContent`: 编辑器中的实际文本内容
/// - `pendingAction`: 待执行的工具栏操作（由 toolbar 写入，representable 消费）
/// - `cursorState`: 光标状态，包含对 UITextView 的引用用于执行文本操作
///
/// ## 工具栏操作流程
/// 1. 用户点击工具栏按钮 → 写入 `pendingAction`
/// 2. `onChange(of: pendingAction)` 监听到变化
/// 3. 调用 `executeAction()` 执行实际操作
/// 4. 将 `pendingAction` 置为 nil
struct MarkdownEditorView: View {
    @Binding var page: WikiPage  ///< 绑定的页面对象，编辑结果直接写回此对象
    @Binding var isEditing: Bool  ///< 绑定外部的编辑状态
    @EnvironmentObject var store: KMStore  ///< 全局知识库存储
    @State private var showLinkPicker = false  ///< 是否显示 WikiLink 页面选择器
    @State private var editorContent: String = ""  ///< 编辑器文本内容（与 page.content 同步）
    @State private var showTagInput = false  ///< 是否显示标签输入框
    @State private var newTagText = ""  ///< 新标签输入框内容
    @State private var showAliasInput = false  ///< 是否显示别名输入框
    @State private var newAliasText = ""  ///< 新别名输入框内容
    @State private var cursorPosition: Int = 0  ///< 当前光标位置（字符偏移）
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)  ///< 当前文本选区
    @State private var cursorState = CursorState()  ///< 光标状态（包含 UITextView executor 引用）
    /// 待执行的编辑器操作（由 toolbar 写入，由 representable 消费）
    @State private var pendingAction: EditorPendingAction?

    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider().background(Color.wikiBorder)
            titleEditor
            tagsEditor
            if showTagInput {
                InlineTagInput(
                    text: $newTagText,
                    onCommit: commitTag,
                    onCancel: { withAnimation { showTagInput = false; newTagText = "" } }
                )
            }
            aliasesEditor
            if showAliasInput {
                InlineTagInput(
                    text: $newAliasText,
                    onCommit: commitAlias,
                    onCancel: { withAnimation { showAliasInput = false; newAliasText = "" } }
                )
            }
            Divider().background(Color.wikiBorder)
            contentEditor
        }
        .background(Color.wikiBackground)
        .onAppear { editorContent = page.content }
        .onDisappear {
            page.content = editorContent
            page.updated = Date()
            store.updatePage(page)
        }
        .sheet(isPresented: $showLinkPicker) {
            WikilinkPickerSheet(page: $page, editorContent: $editorContent)
        }
    }

    // MARK: - Title Editor
    private var titleEditor: some View {
        HStack {
            TextField(Localized.tr("editor.pageTitlePlaceholder"), text: $page.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.wikiText)
                .padding()
        }
        .background(Color.wikiCard)
    }

    // MARK: - Tags Editor
    private var tagsEditor: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(page.tags, id: \.self) { tag in
                    TagChip(tag: tag) {
                        withAnimation { page.tags.removeAll { $0 == tag } }
                    }
                }

                Button(action: { withAnimation { showTagInput.toggle() } }) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus.circle.fill").font(.caption)
                        Text(Localized.tr("editor.addTag")).font(.caption)
                    }
                    .foregroundStyle(.wikiSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.wikiBorder.opacity(0.5))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Aliases Editor
    private var aliasesEditor: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(page.aliases, id: \.self) { alias in
                    AliasChip(alias: alias) {
                        withAnimation { page.aliases.removeAll { $0 == alias } }
                    }
                }

                Button(action: { withAnimation { showAliasInput.toggle() } }) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus.circle.fill").font(.caption)
                        Text(Localized.tr("editor.addAlias")).font(.caption)
                    }
                    .foregroundStyle(.wikiSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.wikiBorder.opacity(0.5))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Content Editor
    private var contentEditor: some View {
        MarkdownTextViewRepresentable(
            text: $editorContent,
            cursorPosition: $cursorPosition,
            selectedRange: $selectedRange,
            cursorState: cursorState
        )
        .frame(maxHeight: .infinity)
        .onChange(of: editorContent) { _, newValue in
            page.content = newValue
        }
        .onChange(of: pendingAction) { _, action in
            guard let action = action else { return }
            executeAction(action)
            pendingAction = nil
        }
    }

    // MARK: - Tag Management
    private func commitTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !page.tags.contains(trimmed) {
            withAnimation { page.tags.append(trimmed) }
        }
        newTagText = ""
        showTagInput = false
    }

    // MARK: - Alias Management
    private func commitAlias() {
        let trimmed = newAliasText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !page.aliases.contains(trimmed) {
            withAnimation { page.aliases.append(trimmed) }
        }
        newAliasText = ""
        showAliasInput = false
    }

    // MARK: - Editor Toolbar
    private var editorToolbar: some View {
        MarkdownEditorToolbar(
            cursorPosition: cursorPosition,
            selectedRange: selectedRange,
            onInsert: { prefix, suffix in
                pendingAction = .insert(prefix: prefix, suffix: suffix)
            },
            onWrap: { wrapper in
                pendingAction = .wrap(wrapper: wrapper)
            },
            onInsertMultiline: { text in
                pendingAction = .insertMultiline(text: text)
            },
            onShowLinkPicker: {
                showLinkPicker = true
            }
        )
    }

    // MARK: - Execute Pending Action
    /// 通过 EditorActionExecutor 直接操作 UITextView，确保光标位置正确。
    private func executeAction(_ action: EditorPendingAction) {
        switch action {
        case .insert(let prefix, let suffix):
            cursorState.executor?.insertAtCursor(prefix: prefix, suffix: suffix)
        case .wrap(let wrapper):
            cursorState.executor?.wrapAtCursor(wrapper: wrapper)
        case .insertMultiline(let text):
            cursorState.executor?.insertMultilineAtCursor(text: text)
        case .wikilink:
            showLinkPicker = true
        }
    }
}
