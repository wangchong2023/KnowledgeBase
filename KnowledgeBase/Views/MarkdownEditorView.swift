import SwiftUI
import UIKit

/// 表示待执行的编辑器操作。
enum EditorPendingAction: Equatable {
    case insert(prefix: String, suffix: String?)
    case wrap(wrapper: String)
    case insertMultiline(text: String)
    case wikilink
}

struct MarkdownEditorView: View {
    @Binding var page: WikiPage
    @Binding var isEditing: Bool
    @EnvironmentObject var store: KMStore
    @State private var showLinkPicker = false
    @State private var editorContent: String = ""
    @State private var showTagInput = false
    @State private var newTagText = ""
    @State private var showAliasInput = false
    @State private var newAliasText = ""
    @State private var cursorPosition: Int = 0
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var cursorState = CursorState()
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
            TextField("页面标题", text: $page.title)
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
                        Text(L.tr("editor.addTag")).font(.caption)
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
                        Text(L.tr("editor.addAlias")).font(.caption)
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
