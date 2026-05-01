import SwiftUI

struct PromptWorkshopView: View {
    @StateObject private var promptService = PromptService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            Section {
                TextEditor(text: $promptService.mindmapPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120)
            } header: {
                Label("思维导图 (Mindmap)", systemImage: "rectangle.stack.badge.person.crop")
            }
            
            Section {
                TextEditor(text: $promptService.quizPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 200)
            } header: {
                Label("知识测验 (Quiz)", systemImage: "questionmark.circle")
            }
            
            Section {
                TextEditor(text: $promptService.slidesPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 150)
            } header: {
                Label("演示大纲 (Slides)", systemImage: "play.rectangle")
            }
            
            Section {
                TextEditor(text: $promptService.reportPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 150)
            } header: {
                Label("深度报告 (Report)", systemImage: "doc.text.magnifyingglass")
            }
            
            Section {
                Button(role: .destructive, action: { showResetAlert = true }) {
                    HStack {
                        Spacer()
                        Text("重置为默认指令")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Prompt 工坊")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    promptService.save()
                    dismiss()
                }
            }
        }
        .alert("确认重置", isPresented: $showResetAlert) {
            Button("重置", role: .destructive) {
                promptService.reset()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这将抹除你所有的自定义 Prompt，并恢复为系统预设。")
        }
    }
}
