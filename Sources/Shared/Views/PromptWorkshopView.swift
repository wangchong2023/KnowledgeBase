import SwiftUI

struct PromptWorkshopView: View {
    @StateObject private var promptService = PromptService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isIntroExpanded = true
    @State private var isMindmapExpanded = false
    @State private var isQuizExpanded = false
    @State private var isSlidesExpanded = false
    @State private var isReportExpanded = false
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            // ── 认知补全：功能简介 ──
            // ── 认知补全：功能简介 (可收缩) ──
            Section {
                DisclosureGroup(isExpanded: $isIntroExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Localized.tr("prompt.workshop.intro.desc"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                            .lineSpacing(4)
                            .padding(.top, 4)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "flask.fill")
                            .font(.title3)
                            .foregroundStyle(.wikiAccent)
                        Text(Localized.tr("prompt.workshop.intro.title"))
                            .font(.headline)
                    }
                }
            }
            .listRowBackground(Color.wikiAccent.opacity(0.05))

            // ── 模块 1：我的快捷指令 (默认展开) ──
            Section {
                ForEach($promptService.userShortcuts) { $item in
                    HStack {
                        TextField(Localized.tr("prompt.workshop.input.placeholder"), text: $item.text)
                            .font(.subheadline)
                        
                        if promptService.userShortcuts.count > 1 {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.wikiSecondary.opacity(0.5))
                        }
                    }
                }
                .onDelete { indices in
                    promptService.userShortcuts.remove(atOffsets: indices)
                }
                .onMove { from, to in
                    promptService.userShortcuts.move(fromOffsets: from, toOffset: to)
                }
                
                Button(action: { 
                    promptService.userShortcuts.append(ShortcutItem(text: Localized.tr("prompt.workshop.add")))
                }) {
                    Label(Localized.tr("prompt.workshop.add"), systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.wikiAccent)
                }
            } header: {
                Label(Localized.tr("prompt.workshop.shortcuts.title"), systemImage: "pin.fill")
            } footer: {
                Text(Localized.tr("prompt.workshop.shortcuts.footer"))
            }

            // ── 模块 2：AI 任务专家配置 (默认折叠) ──
            Section {
                DisclosureGroup(isExpanded: $isMindmapExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Localized.tr("prompt.expert.mindmap.footer"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                        
                        TextEditor(text: $promptService.mindmapPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 120)
                            .padding(4)
                            .background(Color.wikiBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label(Localized.tr("prompt.expert.mindmap.title"), systemImage: "rectangle.stack.badge.person.crop")
                        .font(.subheadline.weight(.medium))
                }
                
                DisclosureGroup(isExpanded: $isQuizExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Localized.tr("prompt.expert.quiz.footer"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                        
                        TextEditor(text: $promptService.quizPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 200)
                            .padding(4)
                            .background(Color.wikiBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label(Localized.tr("prompt.expert.quiz.title"), systemImage: "questionmark.circle")
                        .font(.subheadline.weight(.medium))
                }
                
                DisclosureGroup(isExpanded: $isSlidesExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Localized.tr("prompt.expert.slides.footer"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                        
                        TextEditor(text: $promptService.slidesPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 150)
                            .padding(4)
                            .background(Color.wikiBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label(Localized.tr("prompt.expert.slides.title"), systemImage: "play.rectangle")
                        .font(.subheadline.weight(.medium))
                }
                
                DisclosureGroup(isExpanded: $isReportExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Localized.tr("prompt.expert.report.footer"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                        
                        TextEditor(text: $promptService.reportPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 150)
                            .padding(4)
                            .background(Color.wikiBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label(Localized.tr("prompt.expert.report.title"), systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.medium))
                }
            } header: {
                Text(Localized.tr("prompt.expert.base.title"))
            }
            
            Section {
                Button(role: .destructive, action: { showResetAlert = true }) {
                    HStack {
                        Spacer()
                        Text(Localized.tr("prompt.reset.factory"))
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(Localized.tr("prompt.factory.title"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    promptService.save()
                    HapticManager.shared.trigger(.success)
                    dismiss()
                }) {
                    Text(Localized.tr("misc.done"))
                        .fontWeight(.semibold)
                }
            }
        }
        .alert(Localized.tr("prompt.resetConfirm"), isPresented: $showResetAlert) {
            Button(Localized.tr("misc.reset"), role: .destructive) {
                promptService.reset()
            }
            Button(Localized.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(Localized.tr("prompt.resetWarning"))
        }
    }
}
