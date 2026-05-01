import SwiftUI
import UIKit

// MARK: - Coordinator State Container
/// 用 class 封装光标状态，避免 struct @Binding 在闭包中的捕获问题。
/// 同时作为 EditorActionExecutor 的访问点（coordinator 在 makeCoordinator 时注入）。
final class CursorState: ObservableObject {
    @Published var cursorPosition: Int = 0
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)
    var executor: EditorActionExecutor?
}

// MARK: - Coordinator
final class MarkdownTextViewCoordinator: NSObject, UITextViewDelegate {
    let cursorState: CursorState
    /// 指向活跃的 UITextView，用于 executeAction 直接操作光标
    weak var textView: UITextView?
    var onTextChange: ((String) -> Void)?

    init(cursorState: CursorState) {
        self.cursorState = cursorState
        super.init()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        DispatchQueue.main.async {
            self.cursorState.cursorPosition = textView.selectedRange.location
            self.cursorState.selectedRange = textView.selectedRange
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        DispatchQueue.main.async {
            self.onTextChange?(textView.text ?? "")
        }
    }
}

// MARK: - Markdown Text View Representable
struct MarkdownTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    @Binding var selectedRange: NSRange
    let cursorState: CursorState

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.text = text
        tv.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        tv.textColor = UIColor(Color.wikiText)
        tv.backgroundColor = UIColor(Color.wikiBackground)
        tv.isScrollEnabled = true
        tv.showsVerticalScrollIndicator = true
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.delegate = context.coordinator
        // 将 UITextView 引用存入 coordinator，供 executeAction 使用
        context.coordinator.textView = tv

        context.coordinator.onTextChange = { [self] newText in
            text = newText
        }

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 仅在文本实际不同时更新（避免光标被 updateUIView 重置）
        if uiView.text != text {
            let currentSelected = uiView.selectedRange
            uiView.text = text
            let maxLoc = (text as NSString).length
            if currentSelected.location <= maxLoc {
                uiView.selectedRange = currentSelected
            }
        }
        // 同步 cursorState → binding，推迟到下一个 run loop 避免在 view update 期间修改 state
        let pos = cursorState.cursorPosition
        let range = cursorState.selectedRange
        DispatchQueue.main.async {
            cursorPosition = pos
            selectedRange = range
        }
    }

    func makeCoordinator() -> MarkdownTextViewCoordinator {
        let coordinator = MarkdownTextViewCoordinator(cursorState: cursorState)
        let executor = EditorActionExecutor(coordinator: coordinator)
        cursorState.executor = executor
        return coordinator
    }
}

// MARK: - Cursor-aware Action Executor
/// 持有 coordinator 引用，提供光标感知文本操作。
final class EditorActionExecutor {
    let coordinator: MarkdownTextViewCoordinator

    init(coordinator: MarkdownTextViewCoordinator) {
        self.coordinator = coordinator
    }

    /// 在光标位置插入前缀/后缀
    func insertAtCursor(prefix: String, suffix: String?) {
        guard let tv = coordinator.textView else { return }
        let insertText = suffix.map { prefix + $0 } ?? prefix
        if coordinator.cursorState.selectedRange.length > 0 {
            let range = coordinator.cursorState.selectedRange
            tv.textStorage.replaceCharacters(in: range, with: insertText)
        } else {
            let pos = min(coordinator.cursorState.cursorPosition, (tv.text as NSString).length)
            tv.selectedRange = NSRange(location: pos, length: 0)
            tv.insertText(insertText)
        }
    }

    /// 包裹选区或光标位置
    func wrapAtCursor(wrapper: String) {
        guard let tv = coordinator.textView else { return }
        if coordinator.cursorState.selectedRange.length > 0 {
            let range = coordinator.cursorState.selectedRange
            let selected = (tv.text as NSString).substring(with: range)
            let wrapped = wrapper + selected + wrapper
            tv.textStorage.replaceCharacters(in: range, with: wrapped)
        } else {
            let pos = min(coordinator.cursorState.cursorPosition, (tv.text as NSString).length)
            tv.selectedRange = NSRange(location: pos, length: 0)
            tv.insertText(wrapper + Localized.tr("editor.selectedText") + wrapper)
        }
    }

    /// 在光标位置插入多行文本
    func insertMultilineAtCursor(text: String) {
        guard let tv = coordinator.textView else { return }
        let pos = min(coordinator.cursorState.cursorPosition, (tv.text as NSString).length)
        tv.selectedRange = NSRange(location: pos, length: 0)
        tv.insertText(text)
    }
}

// MARK: - Markdown Editor Toolbar
struct MarkdownEditorToolbar: View {
    let cursorPosition: Int
    let selectedRange: NSRange
    let onInsert: (String, String?) -> Void
    let onWrap: (String) -> Void
    let onInsertMultiline: (String) -> Void
    let onShowLinkPicker: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                EditorToolbarButton(title: "H1", icon: "textformat.size.larger") {
                    onInsert("# ", nil)
                }
                EditorToolbarButton(title: "H2", icon: "textformat.size") {
                    onInsert("## ", nil)
                }
                EditorToolbarButton(title: "H3", icon: "textformat.size.smaller") {
                    onInsert("### ", nil)
                }

                Divider().frame(height: 24).background(Color.wikiBorder)

                EditorToolbarButton(title: Localized.tr("editor.bold"), icon: "bold") {
                    onWrap("**")
                }
                EditorToolbarButton(title: Localized.tr("editor.italic"), icon: "italic") {
                    onWrap("*")
                }
                EditorToolbarButton(title: Localized.tr("editor.code"), icon: "chevron.left.forwardslash.chevron.right") {
                    onWrap("`")
                }

                Divider().frame(height: 24).background(Color.wikiBorder)

                EditorToolbarButton(title: Localized.tr("editor.link"), icon: "link") {
                    onInsert("[[", "]]")
                }
                EditorToolbarButton(title: Localized.tr("editor.list"), icon: "list.bullet") {
                    onInsert("- ", nil)
                }
                EditorToolbarButton(title: Localized.tr("editor.quote"), icon: "text.quote") {
                    onInsert("> ", nil)
                }
                EditorToolbarButton(title: Localized.tr("editor.table"), icon: "tablecells") {
                    onInsertMultiline("\n| \(Localized.tr("editor.tableColumn1")) | \(Localized.tr("editor.tableColumn2")) | \(Localized.tr("editor.tableColumn3")) |\n|------|------|------|\n| \(Localized.tr("editor.tableContent")) | \(Localized.tr("editor.tableContent")) | \(Localized.tr("editor.tableContent")) |\n")
                }
                EditorToolbarButton(title: Localized.tr("editor.divider"), icon: "minus") {
                    onInsertMultiline("\n---\n")
                }

                Divider().frame(height: 24).background(Color.wikiBorder)

                EditorToolbarButton(title: Localized.tr("editor.wikiLink"), icon: "link.circle.fill") {
                    onShowLinkPicker()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.wikiCard)
    }
}
