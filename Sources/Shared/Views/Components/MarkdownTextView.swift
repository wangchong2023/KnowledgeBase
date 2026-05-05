// MarkdownTextView.swift
//
// 作者: Wang Chong
// 功能说明: 用 class 封装光标状态，避免 struct @Binding 在闭包中的捕获问题。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

@preconcurrency import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 协调器状态容器
@MainActor
/// 编辑器光标状态容器
/// 负责跨组件共享光标位置与选区范围，并作为编辑器动作执行器的访问枢纽
final class CursorState: ObservableObject {
    @Published var cursorPosition: Int = 0
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)
    var executor: EditorActionExecutor?
}

// MARK: - 文本视图协调器
@MainActor
/// Markdown 文本视图协调器
/// 负责处理底层 UITextView 的委派回调，实现文本变更同步与光标状态追踪
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
#if os(iOS)
/// Markdown 文本视图包装器组件
/// 负责在 SwiftUI 中嵌入原生高性能 UITextView，支持实时语法高亮感知（由协调器处理）及双向文本绑定
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
#endif

// MARK: - 动作执行器
@MainActor
/// 编辑器动作执行器
/// 负责执行具体编辑命令（如插入、包裹选区），实现光标感知的自动化文本操作
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
            tv.insertText(wrapper + L10n.Editor.tr("selectedText") + wrapper)
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
/// Markdown 编辑器辅助工具栏组件
/// 负责提供 Markdown 常用语法的快速录入入口，增强移动端及桌面端的编辑效率
struct MarkdownEditorToolbar: View {
    let cursorPosition: Int
    let selectedRange: NSRange
    let onInsert: (String, String?) -> Void
    let onWrap: (String) -> Void
    let onInsertMultiline: (String) -> Void
    let onShowLinkPicker: () -> Void
    let onOCR: () -> Void

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

                EditorToolbarButton(title: L10n.Editor.tr("bold"), icon: "bold") {
                    onWrap("**")
                }
                EditorToolbarButton(title: L10n.Editor.tr("italic"), icon: "italic") {
                    onWrap("*")
                }
                EditorToolbarButton(title: L10n.Editor.tr("code"), icon: "chevron.left.forwardslash.chevron.right") {
                    onWrap("`")
                }

                Divider().frame(height: 24).background(Color.wikiBorder)

                EditorToolbarButton(title: L10n.Editor.tr("link"), icon: "link") {
                    onInsert("[[", "]]")
                }
                EditorToolbarButton(title: L10n.Editor.tr("list"), icon: "list.bullet") {
                    onInsert("- ", nil)
                }
                EditorToolbarButton(title: L10n.Editor.tr("quote"), icon: "text.quote") {
                    onInsert("> ", nil)
                }
                EditorToolbarButton(title: L10n.Editor.tr("table"), icon: "tablecells") {
                    onInsertMultiline("\n| \(L10n.Editor.tr("tableColumn1")) | \(L10n.Editor.tr("tableColumn2")) | \(L10n.Editor.tr("tableColumn3")) |\n|------|------|------|\n| \(L10n.Editor.tr("tableContent")) | \(L10n.Editor.tr("tableContent")) | \(L10n.Editor.tr("tableContent")) |\n")
                }
                EditorToolbarButton(title: L10n.Editor.tr("divider"), icon: "minus") {
                    onInsertMultiline("\n---\n")
                }

                Divider().frame(height: 24).background(Color.wikiBorder)

                EditorToolbarButton(title: L10n.Editor.tr("wikiLink"), icon: "link.circle.fill") {
                    onShowLinkPicker()
                }

                Divider().frame(height: 24).background(Color.wikiBorder)

                EditorToolbarButton(title: L10n.Editor.tr("ocrScan"), icon: "text.viewfinder") {
                    onOCR()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.wikiCard)
    }
}
